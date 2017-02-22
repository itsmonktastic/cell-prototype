# Programmed Cell Life

This is a game about programming cells to grow into specific shapes and patterns.

## Quickstart

`./cell stats` : lists challenges in guestimated order of difficulty
`./cell describe CHALLENGE` : Prints the target board state for CHALLENGE and a leaderboard of existing programs
`./cell attempt CHALLENGE MY_NAME` : initializes a program for CHALLENGE with the name MY_NAME. Prints out the file where you should write your program. If the file already exists, runs your program and records the run in a log file.

## How cells work

You start with one cell in the middle of an empty board:
```
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. XX .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. ..
```

The cell carries with it a program. For example:
```
R SPLIT UP
R SUPPRESS UP R
R SUPPRESS SELF B
- SLEEP
B SPLIT UP
B SUPPRESS UP B
```

Each command is made up of three parts:

| Color  | Comand   | Parameters |
| ------ | -------  | ---------- |
| R      | SPLIT    | UP         |
| B      | SUPPRESS | UP B       |
| -      | SLEEP    |            |

Each cell executes its commands starting from the first one. Each cycle, every cell looks for its next active command and executes it.

## Commands
### SPLIT direction
Creates a new cell in the space specified by direction (UP, RIGHT, LEFT or DOWN). If the space is occupied, this command does nothing. The new cell has all the same commands as the existing cell. Those commands also have the same color and active/inactive status.

### SUPPRESS direction color
If there is a cell in the space specified by direction, inactivate all of that cell's commands of the specified color. Inactive commands are skipped over when a cell looks for its next active command.

### SENSE_CELL direction
If there is a cell in the space specified by direction, set this cell's register to TRUE. Otherwise, set this cell's register to FALSE.

### JUMP_IF_TRUE label
If this cell's register is TRUE, update this cell's program counter to point to the next active command after label

### LABEL name
Identify a spot in the list of commands which can be jumped to. This command is not considered when choosing the next active command to execute.

### JUMP label
Unconditionally update this cell's program counter to point to the next active command after label.

### SLEEP
Do nothing for 1 cycle.

### DIE
Remove this cell from the board.

### ACTIVATE direction color
Like SUPPRESS, but makes commands active instead of inactive.

## Order of operations
- Each cycle:
  - For each cell, from oldest to youngest:
    - Look for the next active command after the one that was previously executed. Loops back to the beginning after the last command. If there are no active commands, do nothing.
    - Execute the command.

## Challenges

A challenge is a target board state, e.g.:
```
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. XX .. .. .. .. 
.. .. .. .. XX .. .. .. .. 
.. .. XX XX XX XX XX .. .. 
.. .. .. .. XX .. .. .. .. 
.. .. .. .. XX .. .. .. .. 
.. .. .. .. .. .. .. .. .. 
.. .. .. .. .. .. .. .. ..
```

"XX" means a the space contains a cell. ".." means the space is empty. Your program is a "solution" to the challenge if it ever reaches the target board state. Your program is considered a "stable solution" if it remains in that board state for 20 cycles. Programs are ranked according to:
1. How many errors they have after 100 cycles, if they are not a solution
2. Whether or not the solution is stable
3. How few commands are in the program
4. How many cycles it took to reach the target board state
