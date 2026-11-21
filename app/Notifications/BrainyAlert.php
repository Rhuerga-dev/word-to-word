<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushChannel;
use NotificationChannels\WebPush\WebPushMessage;

/** Aviso de Brainy en la web: tiene hambre o quiere jugar (los mismos textos que la app; nunca culpa). */
class BrainyAlert extends Notification
{
    public function __construct(public string $kind, public string $pet) {}

    public function via(object $notifiable): array
    {
        return [WebPushChannel::class];
    }

    public function title(): string
    {
        return $this->kind === 'hungry' ? "{$this->pet} tiene hambre" : "{$this->pet} quiere jugar";
    }

    public function body(): string
    {
        return $this->kind === 'hungry' ? 'Una palabra nueva es su comida favorita.' : '¿Un rato de Oído o un minuto hablando?';
    }

    public function toWebPush(object $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)
            ->title($this->title())
            ->body($this->body())
            ->icon('/app/icons/icon-192.png?v=2')
            ->badge('/app/icons/icon-192.png?v=2')
            ->tag('brainy')
            ->data(['url' => '/app/'])
            ->options(['TTL' => 3 * 3600]);
    }
}
