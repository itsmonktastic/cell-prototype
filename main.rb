#!/usr/bin/env ruby

class Command
  SPLIT = 'SPLIT'
  SEND_SIGNAL = 'SEND_SIGNAL'
  SENSE_SIGNAL = 'SENSE_SIGNAL'
  JUMP_IF_EQUAL = 'JUMP_IF_EQUAL'

  attr_accessor :type

  def initialize(type)
    self.type = type
  end

  def to_s
    "#{self.type}"
  end
end

class Cell
  attr_accessor :commands, :id, :program_counter

  def initialize()
    self.commands = []
    self.program_counter = 0
  end

  def pretty_id
    sprintf("%02d", self.id)
  end
end

class World
  attr_accessor :grid , :next_cell_id, :cells

  DEFAULT_GRID_SIZE = 9

  def initialize(zygote:)
    self.grid = Array.new(DEFAULT_GRID_SIZE) { Array.new(DEFAULT_GRID_SIZE) }
    middle = DEFAULT_GRID_SIZE / 2
    self.next_cell_id = 0
    self.cells = []

    self.add_cell(zygote, middle, middle)
  end

  def add_cell(cell, row, col)
    current_contents = self.grid[row][col]
    return unless current_contents.nil?

    self.grid[row][col] = cell
    cell.id = self.next_cell_id
    self.next_cell_id += 1
    self.cells << cell
  end
end

def print_world(world)
  world.grid.each do |row|
    row.each do |cell|
      if cell.nil?
        print ".."
      else
        print cell.pretty_id
      end
      print " "
    end
    print "\n"
  end

  print "\n"

  world.cells.each do |cell|
    print_cell(cell)
  end
end

def print_cell(cell)
  printf("%s :\n", cell.pretty_id)
  cell.commands.each_with_index do |command, i|
    print "  "
    print command.to_s
    print " <-" if cell.program_counter == i
    print "\n"
  end
end

def simulate_cell_cycle(world, row, col)
  cell = world.grid[row][col]
  return if cell.nil?
  command = cell.commands[cell.program_counter]
  cell.program_counter += 1
  cell.program_counter %= cell.commands.length

  case command.type
  when Command::SPLIT
    new_cell = Cell.new
    new_cell.commands = cell.commands.dup
    world.add_cell(new_cell, row-1, col)
  else
    raise "unknown command #{command.type}"
  end
end

def simulate_world_cycle(world)
  world.grid.each_with_index do |cells, row|
    cells.each_with_index do |cell, col|
      simulate_cell_cycle(world, row, col)
    end
  end
end

zygote = Cell.new()
zygote.commands << Command.new(Command::SPLIT)
world = World.new(zygote: zygote)

2.times do
  print_world(world)
  simulate_world_cycle(world)
  print "\n"
end
print_world(world)