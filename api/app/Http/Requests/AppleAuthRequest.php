<?php

declare(strict_types=1);

/**
 * AppleAuthRequest — validation wrapper for POST /api/v1/auth/apple.
 *
 * Purpose:
 *   Guard the Apple Sign In endpoint with the minimal required payload shape.
 *   The real verification of the identity token (signature, issuer, audience,
 *   subject) happens downstream in AppleIdentityVerifier; this class only
 *   enforces that the field is present and a string.
 *
 * Dependencies:
 *   - Illuminate\Foundation\Http\FormRequest (Laravel 11 request base).
 *
 * Key concepts:
 *   - Laravel 11 FormRequests default to `authorize() => true`, so no override
 *     is needed for a public (pre-auth) endpoint.
 */

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AppleAuthRequest extends FormRequest
{
    /**
     * Validation rules for the Apple Sign In request body.
     *
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return ['identity_token' => ['required', 'string']];
    }
}
