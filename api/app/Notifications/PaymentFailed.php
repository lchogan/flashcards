<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\Apn\ApnChannel;
use NotificationChannels\Apn\ApnMessage;

/**
 * APNs push dispatched on DID_FAIL_TO_RENEW. Asks the user to open the
 * app and fix their payment method before they fall out of the grace
 * window into expired.
 */
final class PaymentFailed extends Notification
{
    use Queueable;

    /**
     * @return array<int, string>
     */
    public function via(mixed $notifiable): array
    {
        return [ApnChannel::class];
    }

    public function toApn(mixed $notifiable): ApnMessage
    {
        return ApnMessage::create()
            ->title('Payment issue')
            ->body("We couldn't renew your Plus subscription. Tap to review.");
    }
}
