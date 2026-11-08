<?php

namespace App\Notifications;

use Illuminate\Notifications\Notification;
use NotificationChannels\WebPush\WebPushChannel;
use NotificationChannels\WebPush\WebPushMessage;

/** Aviso diario para estudiar, por notificación push. */
class StudyReminder extends Notification
{
    public function __construct(
        public int $reviews,
        public int $newWords,
        public int $streak,
    ) {}

    public function via(object $notifiable): array
    {
        return [WebPushChannel::class];
    }

    public function toWebPush(object $notifiable, Notification $notification): WebPushMessage
    {
        return (new WebPushMessage)
            ->title($this->title())
            ->body($this->body())
            ->icon('/app/icons/icon-192.png')
            ->badge('/app/icons/icon-192.png')
            ->tag('daily-reminder')
            ->data(['url' => '/app/'])
            ->options(['TTL' => 6 * 3600]);
    }

    public function title(): string
    {
        return $this->streak > 0
            ? "No pierdas tu racha de {$this->streak} ".($this->streak === 1 ? 'día' : 'días')
            : 'Hora de practicar inglés';
    }

    public function body(): string
    {
        $parts = [];
        if ($this->reviews > 0) {
            $parts[] = $this->reviews.' '.($this->reviews === 1 ? 'repaso' : 'repasos');
        }
        if ($this->newWords > 0) {
            $parts[] = $this->newWords.' '.($this->newWords === 1 ? 'palabra nueva' : 'palabras nuevas');
        }

        return $parts
            ? 'Hoy te esperan '.implode(' y ', $parts).'. Son unos minutos.'
            : 'Abre Word to Word y practica speaking unos minutos.';
    }
}
