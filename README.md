# Konami-Code-NES

This is a code fragment to implement the Konami Code (you know, U-U-D-D-L-R-L-R-B-A) in an NES program. It is written in 6502 assembler: I assembled it with ASM6, but you should be able to use any compatible program. You will also need the file MARIO.CHR, which is in this repository.

After assembly, open the .nes file in FCEUX and open the hex editor: you should see the button presses stored from 0 - 0A. If you enter the Konami Code, you should see the remaining lives change from 2 to 1C (30 decimal). If you don't enter the code correctly, then obviously this won't happen. The program stores the last 10 button presses, so as long as the KC is the last thing you enter, it will work: this is how I remember the KC working in the actual games.

I put all the variables in zero page, but the code doesn't reference any specific memory address, so you should be able to move them.

The program itself is pretty straightforward: it stores the last 10 button presses in a circular queue (similar to how the keyboard buffer works). I used a flag to check if the buffer is full. The tricky part was wrapping around the pointers when they reached the last buffer address, since you can't natively do modulo operations in 6502 ASM.

This implementation is my own design: I don't know how the KC works in actual games like "Contra". I'd be interested to know if there's an easier way to do it.

Enjoy!
