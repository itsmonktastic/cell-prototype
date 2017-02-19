#!/usr/bin/env ruby
class Command
  SPLIT = 'SPLIT'
  SEND_SIGNAL = 'SEND_SIGNAL'
  SENSE_SIGNAL = 'SENSE_SIGNAL'
  SENSE_CELL = 'SENSE_CELL'
  JUMP_IF_EQUAL = 'JUMP_IF_EQUAL'

  class Direction
    attr_accessor :string_name
    def initialize(string_name)
      self.string_name = string_name
    end
    def to_s
      self.string_name
    end
  end
  UP = Direction.new('UP')
  DOWN = Direction.new('DOWN')
  LEFT = Direction.new('LEFT')
  RIGHT = Direction.new('RIGHT')

  PARAMETERS = {
    SPLIT => [Direction],
    SEND_SIGNAL => [Direction],
    SENSE_SIGNAL => [Direction],
    SENSE_CELL => [Direction],
    JUMP_IF_EQUAL => [Fixnum],
  }

  attr_accessor :type, :parameters

  def initialize(type, parameters=[])
    self.type = type
    
    if parameters.length != PARAMETERS[type].length
      raise "Expected #{PARAMETERS[type].length} parameters, got #{parameters.length}"
    end

    PARAMETERS[type].each_with_index do |param_type, i|
      unless parameters[i].kind_of?(param_type)
        raise "Expected a #{param_type} but got a #{parameters[i].class} at position #{i}"
      end
    end

    self.parameters = parameters
  end

  def to_s
    "#{self.type}"
  end
end

class Cell
  attr_accessor :commands, :id, :program_counter, :is_new

  def initialize()
    self.commands = []
    self.program_counter = 0
    self.is_new = true
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
    return if row < 0 || row >= grid.length
    return if col < 0 || col >= grid[0].length

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
    if cell.program_counter == i
      print "-> "
    else
      print "   "
    end
    print command.to_s
    if command.parameters.length > 0
      print "(#{command.parameters.join(", ")})"
    end

    print "\n"
  end
end

def simulate_cell_cycle(world, row, col)
  cell = world.grid[row][col]
  return if cell.nil? || cell.is_new
  command = cell.commands[cell.program_counter]
  cell.program_counter += 1
  cell.program_counter %= cell.commands.length

  case command.type
  when Command::SPLIT
    new_cell = Cell.new
    new_cell.commands = cell.commands.dup
    case command.parameters[0]
    when Command::UP
      world.add_cell(new_cell, row-1, col)
    when Command::RIGHT
      world.add_cell(new_cell, row, col+1)
    when Command::DOWN
      world.add_cell(new_cell, row+1, col)
    when Command::LEFT
      world.add_cell(new_cell, row, col-1)
    else
      raise "unkown direction #{command.parameters}"
    end
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
  world.grid.each do |cells|
    cells.each do |cell|
      unless cell.nil?
        cell.is_new = false
      end 
    end
  end
end

zygote = Cell.new()
zygote.commands << Command.new(Command::SPLIT, [Command::UP])
zygote.commands << Command.new(Command::SPLIT, [Command::RIGHT])
zygote.commands << Command.new(Command::SPLIT, [Command::DOWN])
zygote.commands << Command.new(Command::SPLIT, [Command::LEFT])
zygote.is_new = false
world = World.new(zygote: zygote)

10.times do
  print_world(world)
  simulate_world_cycle(world)
  print "\n"
end
print_world(world)