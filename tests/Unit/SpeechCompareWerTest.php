<?php

namespace Tests\Unit;

use App\Console\Commands\SpeechCompare;
use PHPUnit\Framework\TestCase;

class SpeechCompareWerTest extends TestCase
{
    public function test_word_error_rate(): void
    {
        $this->assertSame(0.0, SpeechCompare::wer('I think so.', 'i think so'));
        $this->assertEqualsWithDelta(1 / 3, SpeechCompare::wer('I think so', 'I sink so'), 1e-9);
        $this->assertEqualsWithDelta(1 / 3, SpeechCompare::wer('I think so', 'I think'), 1e-9);
        $this->assertSame(1.0, SpeechCompare::wer('hello', ''));
    }
}
