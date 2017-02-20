#!/usr/bin/env ruby
class Command
  SPLIT = 'SPLIT'
  SEND_SIGNAL = 'SEND_SIGNAL'
  SENSE_SIGNAL = 'SENSE_SIGNAL'
  SENSE_CELL = 'SENSE_CELL'
  JUMP_IF_EQUAL = 'JUMP_IF_EQUAL'
  SUPPRESS = 'SUPPRESS'

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
  SELF = Direction.new('SELF')

  class Color
    attr_accessor :string_name
    def initialize(string_name)
      self.string_name = string_name
    end
    def to_s
      self.string_name
    end
  end
  RED = Color.new('RED')
  BLUE = Color.new('BLUE')
  GREEN = Color.new('GREEN')
  YELLOW = Color.new('YELLOW')

  PARAMETERS = {
    SPLIT => [Direction],
    SEND_SIGNAL => [Direction],
    SENSE_SIGNAL => [Direction],
    SENSE_CELL => [Direction],
    JUMP_IF_EQUAL => [Fixnum],
    SUPPRESS => [Direction, Color],
  }

  attr_accessor :type, :parameters, :color, :active

  def initialize(type, parameters=[], color=nil)
    self.type = type
    self.color = color
    self.active = true
    
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

  def pretty_color
    self.color.string_name[0]
  end
end

class Cell
  attr_accessor :commands, :id, :program_counter, :is_new, :row, :col

  def initialize(row, col)
    self.commands = []
    self.program_counter = 0
    self.is_new = true
    self.row = row
    self.col = col
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
    self.next_cell_id = 0
    self.cells = []

    self.add_cell(zygote)
  end

  def add_cell(cell)
    return if cell.row < 0 || cell.row >= grid.length
    return if cell.col < 0 || cell.col >= grid[0].length

    current_contents = self.grid[cell.row][cell.col]
    return unless current_contents.nil?

    self.grid[cell.row][cell.col] = cell
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
    next unless command.active
    if command.color.nil?
      print "  "
    else
      print "#{command.pretty_color} "
    end
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

def simulate_cell_cycle(world, cell)
  return if cell.is_new || cell.commands.none?(&:active)
  while !cell.commands[cell.program_counter].active
    cell.program_counter += 1
  end
  command = cell.commands[cell.program_counter]
  cell.program_counter += 1
  cell.program_counter %= cell.commands.length

  case command.type
  when Command::SPLIT
    existing_cell = cell_at_relative_location(world, cell.row, cell.col, command.parameters[0])
    return unless existing_cell.nil?
    row, col = relative_location(cell.row, cell.col, command.parameters[0])
    new_cell = Cell.new(row, col)
    new_cell.commands = cell.commands.map(&:dup)
    world.add_cell(new_cell)
  when Command::SUPPRESS
    other_cell = cell_at_relative_location(world, cell.row, cell.col, command.parameters[0])
    unless other_cell.nil?
      other_cell.commands.each_with_index do |other_command, i|
        if other_command.color == command.parameters[1]
          other_command.active = false
        end
      end
      if other_cell.commands.any?(&:active)
        while !other_cell.commands[other_cell.program_counter].active
          other_cell.program_counter += 1
        end
      end
    end
  else
    raise "unknown command #{command.type}"
  end
end

def cell_at_relative_location(world, row, col, direction)
  new_row, new_col = relative_location(row, col, direction)
  row = world.grid[new_row]
  row[new_col] unless row.nil?
end

def relative_location(row, col, direction)
  case direction
  when Command::UP
    [row-1, col]
  when Command::RIGHT
    [row, col+1]
  when Command::DOWN
    [row+1, col]
  when Command::LEFT
    [row, col-1]
  when Command::SELF
    [row, col]
  else
    raise "unkown direction #{command.parameters}"
  end
end

def simulate_world_cycle(world)
  world.cells.each do |cell|
    simulate_cell_cycle(world, cell)
  end
  world.grid.each do |cells|
    cells.each do |cell|
      unless cell.nil?
        cell.is_new = false
      end 
    end
  end
end


# Simple grow
simple_grow = Cell.new(4, 4)
simple_grow.commands << Command.new(Command::SPLIT, [Command::UP])
simple_grow.commands << Command.new(Command::SPLIT, [Command::RIGHT])
simple_grow.commands << Command.new(Command::SPLIT, [Command::DOWN])
simple_grow.commands << Command.new(Command::SPLIT, [Command::LEFT])

# Specialize
specialized = Cell.new(4, 4)
specialized.commands << Command.new(Command::SPLIT, [Command::UP], Command::RED)
specialized.commands << Command.new(Command::SUPPRESS, [Command::UP, Command::BLUE], Command::YELLOW)
specialized.commands << Command.new(Command::SUPPRESS, [Command::UP, Command::YELLOW], Command::YELLOW)
specialized.commands << Command.new(Command::SPLIT, [Command::DOWN], Command::BLUE)
specialized.commands << Command.new(Command::SUPPRESS, [Command::DOWN, Command::RED], Command::YELLOW)
specialized.commands << Command.new(Command::SUPPRESS, [Command::DOWN, Command::YELLOW], Command::YELLOW)
specialized.commands << Command.new(Command::SPLIT, [Command::LEFT])
specialized.commands << Command.new(Command::SPLIT, [Command::RIGHT])

specialized2 = Cell.new(4, 4)
specialized2.commands << Command.new(Command::SPLIT, [Command::UP], Command::RED)
specialized2.commands << Command.new(Command::SUPPRESS, [Command::UP, Command::BLUE], Command::YELLOW)
specialized2.commands << Command.new(Command::SUPPRESS, [Command::UP, Command::YELLOW], Command::YELLOW)
specialized2.commands << Command.new(Command::SPLIT, [Command::DOWN], Command::BLUE)
specialized2.commands << Command.new(Command::SUPPRESS, [Command::DOWN, Command::RED], Command::YELLOW)
specialized2.commands << Command.new(Command::SUPPRESS, [Command::DOWN, Command::YELLOW], Command::YELLOW)
specialized2.commands << Command.new(Command::SUPPRESS, [Command::SELF, Command::YELLOW], Command::YELLOW)
specialized2.commands << Command.new(Command::SPLIT, [Command::LEFT])
specialized2.commands << Command.new(Command::SPLIT, [Command::RIGHT])

def test_dna(zygote, dna_name)
  puts dna_name
  world = World.new(zygote: zygote)
  20.times do |i|
    simulate_world_cycle(world)
    puts "#{i} : #{world.cells.count}"
  end
  puts "\n\n"
end

test_dna(simple_grow, 'simple_grow')
test_dna(specialized, 'specialized')
test_dna(specialized2, 'specialized2')