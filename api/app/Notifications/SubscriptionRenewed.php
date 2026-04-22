<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\Apn\ApnChannel;
use NotificationChannels\Apn\ApnMessage;

/**
 * APNs push dispatched when App Store Server Notifications v2 sends a
 * DID_RENEW. Reassures the user that Plus is still active without them
 * having to open the app.
 */
final class SubscriptionRenewed extends Notification
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
            ->title('Plus renewed')
            ->body('Thanks for sticking with us.');
    }
}
