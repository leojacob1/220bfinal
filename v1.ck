SndBuf bufLock => PitShift shiftLock => LPF lpf => dac;
SndBuf bufPots => Gain gainPots => dac;
SndBuf bufKick[16];
Gain gainKick => Gain gainKickMaster;
Gain gainKickBpf => BPF bpfKick => HPF hpfKick => HPF hpfKick2 => gainKickMaster;
gainKickMaster => dac;

0.6 => bufPots.gain;

50 => bpfKick.Q;
400 => hpfKick.freq;
400 => hpfKick2.freq;

for (int i; i < 16; i++) {
  bufKick[i] => gainKick;
  bufKick[i] => gainKickBpf;
  me.dir() + "kick.wav" => bufKick[i].read;
  6 => bufKick[i].gain;
}


me.dir() + "lock.wav" => bufLock.read;
me.dir() + "pots.wav" => bufPots.read;

5000 => lpf.freq;

5 => shiftLock.shift;

// number of the device to open (see: chuck --probe)
0 => int device;
// get command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// the midi event
MidiIn min;
MidiOut mout;
// a message to work with
// open a MIDI device for output
if( !mout.open(0) ) me.exit();
// the message for retrieving data
MidiMsg msg;

// open the device
if( !min.open( device ) ) me.exit();

// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;
144 => int NOTE_ON;
128 => int NOTE_OFF;
176 => int SLIDER;

int padState[64];

// Fill it with 64 zeros
for (0 => int i; i < 64; i++) {
    0 => padState[i];
}

fun setUp() {
  for (56 => int i; i < 64; i++) {
    1 => padState[i];
    mout.send(144, i, 3);
  }
  for (48 => int i; i < 56; i++) {
    0 => padState[i];
    mout.send(144, i, 0);
  }
  0 => isManual;
  mout.send(144, 82, 0);
}

fun playManual(int pad) {
  mout.send(144, pad, 9);
  bufPots.pos(bufPots.samples() / 8 * (pad - 56));
  (bufPots.samples() / 8)::samp => now;
  bufPots.pos(bufPots.samples());
  mout.send(144, pad, 0);
}

fun runPad() {
  while (true) {
    min => now;
    while (min.recv(msg)) {
        msg.data1 => int inputType; // pad number
        msg.data2 => int pad;
        msg.data3 => int velocity;

        // Light it up green at high brightness
        if (inputType == NOTE_ON && isManual && 56 <= pad && 64 > pad) {
          spork ~ playManual(pad);
        } else if (inputType == SLIDER) {
          if (pad == 48) {
            velocity / 127.0 => gainPots.gain;
          } else if (pad == 49) {
            velocity / 127.0 => gainKickMaster.gain;
          } else if (pad == 50) {
            1.0 - (velocity / 127.0) / 2.0 => gainKick.gain;
            velocity / 127.0 => gainKickBpf.gain;
            <<< velocity, gainKick.gain(), gainKickBpf.gain() >>>;
          } else if (inputType == SLIDER && pad == 51) {
            50.0 + (velocity / 127.0 * 1950.0) => bpfKick.freq;
            <<< "freq", bpfKick.freq() >>>;

          }
        } else if (0 <= pad && pad < 64) {
          if (!padState[pad] && inputType == NOTE_ON) {
            1 => padState[pad];
            mout.send(144, pad, 3); // 3 = green high brightness
          } else if (inputType == NOTE_ON) {
            0 => padState[pad];
            mout.send(144, pad, 0); // 3 = green high brightness
          }
        } else if (pad == 82) {
          if (isManual && inputType == NOTE_ON) {
            0 => isManual;
            mout.send(144, 82, 0);
            for (56 => int i; i < 64; i++) {
              if (padState[i]) mout.send(144, i, 3);
            }
          } else if (inputType == NOTE_ON) {
            1 => isManual;
            mout.send(144, 82, 3);
            for (56 => int i; i < 64; i++) {
              mout.send(144, i, 0);
            }
          }
        } else if (pad == 83) {
          if (isDoubleKick && inputType == NOTE_ON) {
            0 => isDoubleKick;
            mout.send(144, 83, 0);
          } else if (inputType == NOTE_ON) {
            1 => isDoubleKick;
            mout.send(144, 83, 3);
          }
        }

        10::ms => now;
        
    }
  }
}

0 => int isManual;
fun playPots() {
  while (true) {
    0 => int hasPlayed;
    if (!isManual) {
      for (56 => int i; i < 64; i++) {
        if (padState[i]) {
          1 => hasPlayed;
          bufPots.pos(bufPots.samples() / 8 * (i - 56));
          (bufPots.samples() / 8)::samp => now;
        } else {
          bufPots.pos(bufPots.samples());
        }
      }
    }
    if (!hasPlayed) (bufPots.samples() / 8)::samp => now;
  }
}

0 => int isDoubleKick;
fun playKick() {
  while (true) {
    for (48 => int i; i < 56; i++) {
      if (padState[i]) {
        if (isDoubleKick) {
          bufKick[i - 48].pos(0);
          (bufPots.samples() / 16)::samp => now;
          bufKick[i - 48 + 8].pos(0);
          (bufPots.samples() / 16)::samp => now;
        } else {
          bufKick[i - 48].pos(0);
          (bufPots.samples() / 8)::samp => now;
        }

      } else {
        (bufPots.samples() / 8)::samp => now;
      }
    }
  }
}



spork ~ setUp();
spork ~ runPad();
spork ~ playPots();
spork ~ playKick();
eon => now;



// while (true) {
//   0 => bufLock.pos;
//   0 => bufPots.pos;
//   0 => bufKick.pos;
//   4::second => now;
// }
