/* --------- SETUP --------- */
SndBuf bufLock => PitShift shiftLock => LPF lpf => dac;
SndBuf bufPots => Gain gainPots => dac;
SndBuf bufKick[16];
Gain gainKick => Gain gainKickMaster;
Gain gainKickBpf => BPF bpfKick => gainKickMaster;
gainKickMaster => dac;

SndBuf bufFadi => ADSR envFadi => PitShift shiftFadi1 => PitShift shiftFadi2 => Gain gainFadi => JCRev revFadi => dac;

envFadi.set(5::ms, 5::ms, 0.7, 100::ms);
-2 => shiftFadi1.shift;
1.0 => bufFadi.rate;
8.0 => bufFadi.gain;
0.07 => revFadi.mix;
0.4 => revFadi.gain;
  
0.6 => bufPots.gain;

50 => bpfKick.Q;

for (int i; i < 16; i++) {
  bufKick[i] => gainKick;
  bufKick[i] => gainKickBpf;
  me.dir() + "kick.wav" => bufKick[i].read;
  bufKick[i].samples() => bufKick[i].pos;
  9 => bufKick[i].gain;
}

me.dir() + "lock.wav" => bufLock.read;
me.dir() + "pots.wav" => bufPots.read;
me.dir() + "fadi.wav" => bufFadi.read;

bufLock.samples() => bufLock.pos;
bufPots.samples() => bufPots.pos;
bufFadi.samples() => bufFadi.pos;

5000 => lpf.freq;

5 => shiftLock.shift;

(bufPots.samples() / 8)::samp => dur eighth;
(bufPots.samples() / 16)::samp => dur sixteenth;

/* --------- MIDI SETUP --------- */

0 => int device;
if( me.args() ) me.arg(0) => Std.atoi => device;

MidiIn min;
MidiOut mout;

if( !mout.open(0) ) me.exit();
MidiMsg msg;

if( !min.open( device ) ) me.exit();

<<< "MIDI device:", min.num(), " -> ", min.name() >>>;
144 => int NOTE_ON;
128 => int NOTE_OFF;
176 => int SLIDER;

0 => int OFF;
3 => int RED;
9 => int GREEN;

int padState[64];

// Fill it with 64 zeros
for (0 => int i; i < 64; i++) {
    0 => padState[i];
}

fun setUp() {
  for (56 => int i; i < 64; i++) {
    0 => padState[i];
    mout.send(144, i, 0);
  }
  for (48 => int i; i < 56; i++) {
    0 => padState[i];
    mout.send(144, i, 0);
  }
  for (40 => int i; i < 48; i++) {
    0 => padState[i];
    mout.send(144, i, 0);
  }
  mout.send(144, 82, OFF);
  mout.send(144, 83, OFF);
  mout.send(144, 84, OFF);
  mout.send(144, 85, OFF);
}

fun playManualPots(int pad) {
  mout.send(144, pad, GREEN);
  bufPots.pos(bufPots.samples() / 8 * (pad - 56));
  eighth => now;
  bufPots.pos(bufPots.samples());
  <<< "TURN OFF PAD", pad >>>;
  mout.send(144, pad, OFF);
}

fun playManualFadi() {
  mout.send(144, 85, RED);
  6000 => bufFadi.pos;
  envFadi.keyOn();
  25::ms => now;
  envFadi.keyOff();
  100::ms => now;
  mout.send(144, 85, OFF);
}

fun runPad() {
  Shred manualPotsSh;
  Shred manualFadiSh;
  int activeManualPad;
  while (true) {
    min => now;
    while (min.recv(msg)) {
        msg.data1 => int inputType; // pad number
        msg.data2 => int pad;
        msg.data3 => int velocity;

        // Light it up green at high brightness
        if (inputType == NOTE_ON && isManualPots && 56 <= pad && 64 > pad) {
          if (manualPotsSh.id()) {
            Machine.remove(manualPotsSh.id());
            mout.send(144, activeManualPad, OFF);
          }
          pad => activeManualPad;
          spork ~ playManualPots(pad) @=> manualPotsSh;
        } else if (inputType == NOTE_ON && isManualFadi && pad == 85) {
          if (manualFadiSh.id()) {
            Machine.remove(manualFadiSh.id());
            mout.send(144, 85, 0);
          }
          spork ~ playManualFadi();
        } else if (inputType == SLIDER) {
          if (pad == 48) {
            velocity / 127.0 => gainPots.gain;
          } else if (pad == 49) {
            velocity / 127.0 => gainKickMaster.gain;
          } else if (pad == 50) {
            (1.0 - (velocity / 127.0)) / 2.0 => gainKick.gain;
            velocity / 127.0 => gainKickBpf.gain;
          } else if (pad == 51) {
            50.0 + (velocity / 127.0 * 1950.0) => bpfKick.freq;
          } else if (pad == 52) {
            velocity / 127.0 => gainFadi.gain;
          } else if (pad == 53) {
            Math.pow(2, (velocity / 127.0 * 20.0 - 18.0) / 12.0) => shiftFadi2.shift;
          }
        } else if (0 <= pad && pad < 64) {
          if (!padState[pad] && inputType == NOTE_ON) {
            1 => padState[pad];
            mout.send(144, pad, RED); // 3 = green high brightness
          } else if (inputType == NOTE_ON) {
            0 => padState[pad];
            mout.send(144, pad, OFF);
          }
        } else if (pad == 82 && inputType == NOTE_ON) {
          if (isManualPots) {
            if (manualPotsSh.id()) Machine.remove(manualPotsSh.id());
            0 => isManualPots;
            mout.send(144, 82, OFF);
            for (56 => int i; i < 64; i++) {
              if (padState[i]) mout.send(144, i, RED);
            }
          } else {
            1 => isManualPots;
            mout.send(144, 82, GREEN);
            for (56 => int i; i < 64; i++) {
              mout.send(144, i, OFF);
            }
          }
        } else if (pad == 83 && inputType == NOTE_ON) {
          if (isDoubleKick) {
            0 => isDoubleKick;
            mout.send(144, 83, OFF);
          } else {
            1 => isDoubleKick;
            mout.send(144, 83, GREEN);
          }
        } else if (pad == 84 && inputType == NOTE_ON) {
          if (manualFadiSh.id()) Machine.remove(manualFadiSh.id());
          if (isManualFadi) {
            0 => isManualFadi;
            mout.send(144, 84, OFF);
            mout.send(144, 85, OFF);
            for (40 => int i; i < 48; i++) {
              if (padState[i]) mout.send(144, i, RED);
            }
          } else {
            1 => isManualFadi;
            mout.send(144, 84, GREEN);
            for (40 => int i; i < 48; i++) {
              mout.send(144, i, OFF);
            }
          }
        }     
    }
  }
}

0 => int isManualPots;
fun playPots() {
  while (true) {
    0 => int hasPlayed;
    if (!isManualPots) {
      for (56 => int i; i < 64; i++) {
        if (isManualPots) {
          bufPots.pos(bufPots.samples());
        } else if (padState[i]) {
          1 => hasPlayed;
          bufPots.pos(bufPots.samples() / 8 * (i - 56));
          eighth => now;
        } else {
          bufPots.pos(bufPots.samples());
        }
      }
    }
    if (!hasPlayed) eighth => now;
  }
}

0 => int isDoubleKick;
fun playKick() {
  while (true) {
    for (48 => int i; i < 56; i++) {
      if (padState[i]) {
        if (isDoubleKick) {
          bufKick[i - 48].pos(0);
          sixteenth => now;
          bufKick[i - 48 + 8].pos(0);
          sixteenth => now;
        } else {
          bufKick[i - 48].pos(0);
          eighth => now;
        }

      } else {
        eighth => now;
      }
    }
  }
}

0 => int isManualFadi;
fun playFadi() {
  while (true) {
    if (!isManualFadi) {
      for (40 => int i; i < 48; i++) {
        if (isManualFadi) {
          bufPots.pos(bufPots.samples());
        } else if (padState[i]) {
          6000 => bufFadi.pos;
          envFadi.keyOn();
          25::ms => now;
          envFadi.keyOff();
          eighth - 25::ms => now;
        } else {
          eighth => now;
        }
      }
    } else {
      eighth => now;
    }
  }
}

spork ~ setUp();
spork ~ runPad();
spork ~ playPots();
spork ~ playKick();
spork ~ playFadi();

eon => now;



// while (true) {
//   0 => bufLock.pos;
//   0 => bufPots.pos;
//   0 => bufKick.pos;
//   4::second => now;
// }
