<?php

namespace App\Services;

/**
 * FSRS (Free Spaced Repetition Scheduler, versión 4.5): el método moderno de Anki.
 * Cada palabra guarda dos números:
 * - stability (S): cuántos días tarda tu memoria en bajar al 90 % de acierto.
 * - difficulty (D): de 1 (fácil) a 10 (difícil) para ti.
 * Con la retención deseada al 90 %, el próximo repaso es justo a S días.
 */
class Fsrs
{
    /** Pesos por defecto de FSRS-4.5 (entrenados con millones de repasos de Anki). */
    private const W = [0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755];

    private const DECAY = -0.5;

    private const FACTOR = 19 / 81;

    public const GRADE = ['again' => 1, 'hard' => 2, 'good' => 3, 'easy' => 4];

    public function __construct(private float $retention = 0.9, private int $maxDays = 365) {}

    /** Probabilidad de recordar la palabra pasados $days días. */
    public function retrievability(float $days, float $stability): float
    {
        return (1 + self::FACTOR * $days / $stability) ** self::DECAY;
    }

    /** Días hasta el próximo repaso para una estabilidad dada. */
    public function interval(float $stability): int
    {
        $days = $stability / self::FACTOR * ($this->retention ** (1 / self::DECAY) - 1);

        return (int) max(1, min($this->maxDays, round($days)));
    }

    /** Primera vez que se califica una palabra. @return array{stability: float, difficulty: float} */
    public function first(string $grade): array
    {
        $g = self::GRADE[$grade];

        return ['stability' => self::W[$g - 1], 'difficulty' => $this->initialDifficulty($g)];
    }

    /**
     * Nuevo estado tras un repaso.
     *
     * @return array{stability: float, difficulty: float}
     */
    public function next(float $stability, float $difficulty, float $elapsedDays, string $grade): array
    {
        $g = self::GRADE[$grade];
        $w = self::W;
        $r = $this->retrievability(max(0, $elapsedDays), $stability);

        $d = $difficulty - $w[6] * ($g - 3);
        $d = $w[7] * $this->initialDifficulty(3) + (1 - $w[7]) * $d;   // vuelve poco a poco a la media
        $d = $this->clampD($d);

        if ($g === 1) {
            $s = $w[11] * $difficulty ** -$w[12] * (($stability + 1) ** $w[13] - 1) * exp($w[14] * (1 - $r));
            $s = min($s, $stability);
        } else {
            $bonus = $g === 2 ? $w[15] : ($g === 4 ? $w[16] : 1);
            $s = $stability * (1 + exp($w[8]) * (11 - $difficulty) * $stability ** -$w[9] * (exp($w[10] * (1 - $r)) - 1) * $bonus);
        }

        return ['stability' => max(0.1, $s), 'difficulty' => $d];
    }

    private function initialDifficulty(int $g): float
    {
        return $this->clampD(self::W[4] - ($g - 3) * self::W[5]);
    }

    private function clampD(float $d): float
    {
        return max(1, min(10, $d));
    }
}
