# queue-operations<br>
An assembly program that processes user-input commands to manipulate circular first-in first-out queues. The FRDM-KL05Z board from NXP is used.

![ProgramResults](https://github.com/Helena-Lynd/queue-operations/blob/main/program-output.png?raw=true)

## Description<br>
When a microcontroller is given a user-input command, a certain flag is set which indicates that input has been received and needs to be processed. This program uses a serial I/O driver, which interrupts the program when the flag is set in order to process the command. The program can process commands to enqueue a character, dequeue a character, check the size and starting and ending address of the queue, print the contents of the queue, and print a help message that clarifies the commands.
## Getting Started<br>
### Dependencies
- A method to compile the source files into an executable (e.g. Keil uVision5)
- KL05 board connected to a terminal (e.g. PuTTY)
### Installing
- Download the source files provided to your directory of choice
```
git clone git@github.com:Helena-Lynd/queue-operations.git
```
- Compile the source files into an executable
  - If using an IDE, use the "Build" or "Rebuild" feature
### Executing
- Load the executable to your boards flash memory
  - If using an IDE, use the "Download" feature
- Run the program with a connected terminal window open
  - The board has a button that can be pressed to initiate the program
- Input one of the following commands (uppercase and lowercase commands are both accepted):
  - D : (Dequeue) Removes a character from the queue. The queue follows a first-in first-out format. If the queue is empty, prints a failure message.
  - E : (Enqueue) Enqueues a character to the queue. If the queue is full, prints a failure message.
  - H : (Help) Prints a help message to clarify commands.
  - P : (Print) Prints the contents of the queue, from first in to last in.
  - S : (Status) Prints the starting address of the queue, ending address of the queue, and number of elements currently enqueued.
## Modifying
The queue size is set to 4. This can be changed by updating the value of "Q_BUF_SZ" in the EQUates section of the asm-src-code file.
## Authors<br>
Helena Lynd
