<?php

declare(strict_types=1);

/**
 * Feature tests for ReviewReplayer.
 *
 * Purpose:
 *   Verify that ReviewReplayer correctly recomputes Card FSRS state from its
 *   review log — including "last state_after wins" ordering, lapse counting,
 *   and safe no-op behaviour for non-existent cards.
 *
 * Dependencies:
 *   - App\Services\Fsrs\ReviewReplayer
 *   - App\Models\{Card, Deck, Review, User}
 *
 * Key concepts:
 *   - RefreshDatabase is applied via Pest.php's `uses(...)->in('Feature')` binding.
 *   - Tests exercise the replayer directly rather than via the queued job to keep
 *     assertions focused on replay logic, not queue mechanics.
 */

use App\Models\Card;
use App\Models\Deck;
use App\Models\Review;
use App\Models\User;
use App\Services\Fsrs\ReviewReplayer;
use Illuminate\Support\Str;

test('replay updates card state from latest review\'s state_after', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create(['state' => 'new']);

    Review::create([
        'id' => (string) Str::orderedUuid(),
        'card_id' => $card->id,
        'user_id' => $u->id,
        'rating' => 3,
        'rated_at_ms' => 1000,
        'state_before' => ['state' => 'new'],
        'state_after' => ['state' => 'learning', 'stability' => 1.2, 'difficulty' => 5.4, 'due_at_ms' => 2000],
        'scheduler_version' => 'fsrs-6',
        'updated_at_ms' => 1000,
    ]);

    (new ReviewReplayer)->replay($card->id);

    $card->refresh();
    expect($card->state)->toBe('learning')
        ->and($card->stability)->toBe(1.2)
        ->and($card->difficulty)->toBe(5.4)
        ->and($card->due_at_ms)->toBe(2000)
        ->and($card->last_reviewed_at_ms)->toBe(1000)
        ->and($card->reps)->toBe(1);
});

test('later review supersedes earlier when replayed', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create();

    foreach ([[1000, 'learning', 1.0], [2000, 'review', 5.0]] as [$at, $state, $stab]) {
        Review::create([
            'id' => (string) Str::orderedUuid(),
            'card_id' => $card->id,
            'user_id' => $u->id,
            'rating' => 3,
            'rated_at_ms' => $at,
            'state_before' => [],
            'state_after' => ['state' => $state, 'stability' => $stab],
            'scheduler_version' => 'fsrs-6',
            'updated_at_ms' => $at,
        ]);
    }

    (new ReviewReplayer)->replay($card->id);

    expect($card->fresh()->state)->toBe('review')
        ->and($card->fresh()->stability)->toBe(5.0)
        ->and($card->fresh()->reps)->toBe(2);
});

test('lapses are counted correctly from rating=1 reviews', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create();

    // 4 reviews total: 2 with rating=1 (Again/lapse), 1 with rating=3, 1 with rating=2
    foreach ([[1000, 1], [2000, 3], [3000, 1], [4000, 2]] as [$at, $rating]) {
        Review::create([
            'id' => (string) Str::orderedUuid(),
            'card_id' => $card->id,
            'user_id' => $u->id,
            'rating' => $rating,
            'rated_at_ms' => $at,
            'state_before' => [],
            'state_after' => ['state' => 'review', 'stability' => 1.0],
            'scheduler_version' => 'fsrs-6',
            'updated_at_ms' => $at,
        ]);
    }

    (new ReviewReplayer)->replay($card->id);

    expect($card->fresh()->reps)->toBe(4)
        ->and($card->fresh()->lapses)->toBe(2);
});

test('replay is a no-op for nonexistent card', function () {
    // Should not throw — ReviewReplayer returns early when card is not found.
    (new ReviewReplayer)->replay((string) Str::orderedUuid());
    expect(true)->toBeTrue();
});
