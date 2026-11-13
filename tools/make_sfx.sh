#!/bin/sh
# Synthesise UI/game sound effects with sox (oscillators + envelopes; no samples, no AI). CC0 by this project.
set -e
D=assets/audio/synth/sfx
sox -n -r 44100 -b 16 -e signed-integer $D/pop.wav synth 0.09 sine 700-1600 fade q 0.003 0.09 0.06 gain -3
sox -n -r 44100 -b 16 -e signed-integer $D/whoosh.wav synth 0.28 pinknoise fade q 0.04 0.28 0.2 bandpass 1400 1.2 gain -2
sox -n -r 44100 -b 16 -e signed-integer $D/chime.wav synth 0.9 sine 880 sine 1320 remix 1,2 fade q 0.005 0.9 0.8 gain -6
sox -n -r 44100 -b 16 -e signed-integer $D/coin.wav synth 0.07 square 1320 : synth 0.18 square 1760 fade q 0.002 0.18 0.15 gain -14
sox -n -r 44100 -b 16 -e signed-integer $D/click.wav synth 0.03 sine 1200 fade q 0.001 0.03 0.02 gain -6
sox -n -r 44100 -b 16 -e signed-integer $D/unlock.wav synth 0.5 sine 523 : synth 0.5 sine 659 : synth 0.8 sine 784 fade q 0.01 0.8 0.6 gain -8
