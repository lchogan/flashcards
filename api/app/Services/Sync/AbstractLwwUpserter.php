<?php

declare(strict_types=1);

/**
 * AbstractLwwUpserter — shared base for last-write-wins upsert logic.
 *
 * Purpose:
 *   Extracts the rule-of-four duplication that exists across TopicUpserter,
 *   DeckUpserter, SubTopicUpserter, CardUpserter, and SessionUpserter into a
 *   single place. Subclasses declare only what is unique to the entity:
 *   the model class, an ownership check, and the field-mapping step.
 *
 * Dependencies:
 *   - App\Models\User (ownership gating)
 *   - Illuminate\Database\Eloquent\Model (generic model operations)
 *   - Illuminate\Support\Facades\DB (transactional LWW write)
 *   - App\Services\Sync\RecordUpserter (implemented interface)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - TOCTOU fix: the stale-check and write are wrapped in DB::transaction with
 *     lockForUpdate(), so concurrent pushes of the same id are serialised at the
 *     database level and LWW semantics are guaranteed.
 *   - Partial-update preservation: the preserve() helper returns the EXISTING value
 *     when a key is absent from $row, and returns the incoming value (even null)
 *     when the key is present. This prevents absent optional fields from
 *     silently overwriting existing data.
 *   - UUID preservation: new models have $model->id set explicitly before save()
 *     so HasUuids does not regenerate the client-supplied UUID.
 *
 * Not suitable for:
 *   - CardSubTopicUpserter — two-part ownership check (card's deck + sub_topic
 *     must be on the same deck) cannot be expressed via checkOwnership().
 *   - ReviewUpserter — insert-only semantics; there is no LWW update path.
 */

namespace App\Services\Sync;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * Template-method base class for LWW upserts with transactional row-locking
 * and partial-update-preserving field application.
 *
 * Subclasses declare:
 *   - modelClass(): the Eloquent model (class-string<Model>)
 *   - checkOwnership(): return a failure reason or null to proceed
 *   - applyFields(): copy row fields onto the model using preserve() helpers
 *
 * The base class handles:
 *   - missing_id guard
 *   - ownership-reason short-circuit
 *   - DB transaction + lockForUpdate on the target row (TOCTOU fix)
 *   - stale LWW check (>=, so equal timestamps are also rejected for idempotency)
 *   - UUID preservation (new $modelClass; $model->id = $id)
 *   - deleted_at_ms with partial-update semantics
 *   - updated_at_ms assignment
 */
abstract class AbstractLwwUpserter implements RecordUpserter
{
    /**
     * Return the Eloquent model class-string for this entity.
     *
     * @return class-string<Model>
     */
    abstract protected function modelClass(): string;

    /**
     * Check whether the authenticated user may write the record identified by $id.
     *
     * Called after the missing_id guard, before the transactional LWW block.
     * Return a non-null reason string to reject immediately; return null to proceed.
     *
     * Note: this check does a pre-transaction SELECT. It is intentionally kept
     * outside the transaction to avoid holding a lock on the ownership-parent row
     * (e.g. the parent Deck) during the upsert of the child entity. For ownership
     * checks, the risk of a TOCTOU race here is low (deck transfers do not occur
     * in normal usage), and the inner lockForUpdate covers the entity row itself.
     *
     * @param  User  $user  Authenticated user performing the push.
     * @param  string  $id  UUID of the record being upserted.
     * @param  array<string, mixed>  $row  Full row payload from the client.
     * @return string|null Rejection reason, or null to proceed.
     */
    abstract protected function checkOwnership(User $user, string $id, array $row): ?string;

    /**
     * Copy row fields onto the model.
     *
     * Called inside the DB transaction after the LWW check passes. The base
     * class sets updated_at_ms and deleted_at_ms after this call returns, so
     * subclasses must not set those fields here.
     *
     * Use $this->preserve($row, $existing, 'field_name') for nullable optional
     * fields so that absent keys do not overwrite existing data.
     *
     * @param  Model  $model  The model instance (new or fetched existing).
     * @param  User  $user  Authenticated user; needed for user_id on top-level entities.
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  The pre-lock existing record, or null on create.
     */
    abstract protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void;

    /**
     * Attempt to upsert the record using last-write-wins conflict resolution.
     *
     * Guard order:
     *   1. Blank id → missing_id
     *   2. Ownership check (subclass) → forbidden or custom reason
     *   3. DB transaction: lockForUpdate on entity row, stale check, write
     *
     * @param  User  $user  Authenticated owner.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        if ($id === '') {
            return new UpsertResult(false, 'missing_id');
        }

        if ($reason = $this->checkOwnership($user, $id, $row)) {
            return new UpsertResult(false, $reason);
        }

        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        $modelClass = $this->modelClass();

        return DB::transaction(function () use ($modelClass, $user, $id, $row, $incoming): UpsertResult {
            /** @var Model|null $existing */
            $existing = $modelClass::query()->where('id', $id)->lockForUpdate()->first();

            // LWW: reject stale or equal timestamps. Equality is rejected so that
            // retried pushes with the same clock value are idempotent (no double-write).
            if ($existing && (int) $existing->getAttribute('updated_at_ms') >= $incoming) {
                return new UpsertResult(false, 'stale');
            }

            // UUID preservation: explicitly set id before save() so HasUuids
            // skips its own UUID generation (id is not in $fillable).
            /** @var Model $model */
            $model = $existing ?? new $modelClass;
            if (! $existing) {
                // setAttribute avoids PHPStan's property.notFound on the base Model class.
                $model->setAttribute('id', $id);
            }

            $this->applyFields($model, $user, $row, $existing);

            // Base class owns these two fields so subclasses cannot forget them.
            $model->setAttribute('updated_at_ms', $incoming);
            $model->setAttribute('deleted_at_ms', $this->preserve($row, $existing, 'deleted_at_ms', castInt: true));

            $model->save();

            return new UpsertResult(true);
        });
    }

    /**
     * Partial-update-preserving field resolver.
     *
     * Returns the EXISTING model attribute when $key is absent from $row,
     * preventing absent optional fields from silently overwriting stored data.
     * When $key is present (even explicitly null), the incoming value wins.
     *
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock model, or null on create.
     * @param  string  $key  The field name to resolve.
     * @param  bool  $castInt  When true, coerce non-null incoming values to int.
     * @return mixed Resolved value to assign to the model attribute.
     */
    protected function preserve(array $row, ?Model $existing, string $key, bool $castInt = false): mixed
    {
        if (! array_key_exists($key, $row)) {
            // Key absent from payload — preserve whatever is already stored.
            return $existing?->getAttribute($key);
        }

        $v = $row[$key];
        if ($v === null) {
            return null;
        }

        return $castInt ? (int) $v : $v;
    }
}
