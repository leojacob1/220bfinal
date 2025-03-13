// Load your sample
SndBuf buf;
Gain g => dac;
me.dir() + "lock.wav" => buf.read;

// Play once
1 => buf.loop;
0 => buf.pos;

// Optional: Slow it down or speed it up (pitch shift)
1.0 => buf.rate; // no pitch shift

// Create bandpass filters to simulate formants
BPF f1 => g;
BPF f2 => g;
BPF f3 => g;

// Connect SndBuf to each filter
buf => f1;
buf => f2;
buf => f3;

// Boost the filter outputs
2 => g.gain;

// Function to set formant frequencies and bandwidth (Q)
fun void setFormants(float shift) {
    // Base vowel formants (e.g., "A" vowel)
    [400, 800, 1150] @=> int freqs[];

    // Shift all formants by multiplying frequency
    for (0 => int i; i < freqs.cap(); i++) {
        freqs[i] * shift => float shiftedFreq;

        // Set filter freqs
        if (i == 0) shiftedFreq => f1.freq;
        if (i == 1) shiftedFreq => f2.freq;
        if (i == 2) shiftedFreq => f3.freq;
    }

    // Set filter bandwidths via Q
    10 => f1.Q;
    10 => f2.Q;
    10 => f3.Q;
}

// Try different shift amounts
setFormants(0.1); // shifts the formants down
1::second => now;

setFormants(1.2); // shifts the formants up
1::second => now;

// Let it play a bit more
2::second => now;
