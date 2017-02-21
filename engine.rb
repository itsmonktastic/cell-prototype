class Command
  SPLIT = 'SPLIT'
  SEND_SIGNAL = 'SEND_SIGNAL'
  SENSE_SIGNAL = 'SENSE_SIGNAL'
  SENSE_CELL = 'SENSE_CELL'
  JUMP_IF_TRUE = 'JUMP_IF_TRUE'
  SUPPRESS = 'SUPPRESS'
  DIE = 'DIE'
  LABEL = 'LABEL'
  SLEEP = 'SLEEP'
  JUMP = 'JUMP'
  ACTIVATE = 'ACTIVATE'

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
  NONE = Color.new('NONE')
  RED = Color.new('RED')
  BLUE = Color.new('BLUE')
  GREEN = Color.new('GREEN')
  YELLOW = Color.new('YELLOW')
  PURPLE = Color.new('PURPLE')
  ORANGE = Color.new('ORANGE')

  PARAMETERS = {
    SPLIT => [Direction],
    SEND_SIGNAL => [Direction],
    SENSE_SIGNAL => [Direction],
    SENSE_CELL => [Direction],
    JUMP_IF_TRUE => [String],
    SUPPRESS => [Direction, Color],
    DIE => [],
    LABEL => [String],
    SLEEP => [],
    JUMP => [String],
    ACTIVATE => [Direction, Color]
  }

  attr_accessor :type, :parameters, :color, :active

  def initialize(type, parameters=[], color=NONE)
    self.type = type
    self.color = color
    self.active = true
    
    if parameters.length != PARAMETERS[type].length
      raise "Expected #{PARAMETERS[type].length} parameters, got #{parameters.length}, for #{type}"
    end

    PARAMETERS[type].each_with_index do |param_type, i|
      unless parameters[i].kind_of?(param_type)
        raise "Expected a #{param_type} for command #{type} but got a #{parameters[i].class} at position #{i}"
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
  attr_accessor :commands, :id, :program_counter, :is_new, :row, :col, :register, :parent

  def initialize(row, col)
    self.commands = []
    self.program_counter = 0
    self.is_new = true
    self.row = row
    self.col = col
    self.register = false
    self.parent = nil
  end

  def pretty_id
    sprintf("%02d", self.id)
  end

  def pretty_register
    self.register ? '1' : '0'
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

def print_grid(grid, log)
  grid.each do |row|
    row.each do |cell|
      if cell.nil?
        log.write("..")
      else
        log.write(cell.pretty_id)
      end
      log.write(" ")
    end
    log.write("\n")
  end
end

def print_world(world, log, long_log)
  print_grid(world.grid, log)
  print_grid(world.grid, long_log)

  log.write("\n")

  world.cells.each do |cell|
    print_cell(cell, long_log)
  end
end

def print_cell(cell, log)
  log.write(sprintf("%s (%s) (%s):\n", cell.pretty_id, cell.pretty_register, cell.parent&.pretty_id))
  cell.commands.each_with_index do |command, i|
    next unless command.active
    if command.color.nil?
      log.write("  ")
    else
      log.write("#{command.pretty_color} ")
    end
    if cell.program_counter == i
      log.write("-> ")
    else
      log.write("   ")
    end
    log.write(command.to_s)
    if command.parameters.length > 0
      log.write("(#{command.parameters.join(", ")})")
    end

    log.write("\n")
  end
end

def simulate_cell_cycle(world, cell)
  return if cell.is_new || no_active_commands?(cell)
  move_past_inactive_commands(cell)
  command = cell.commands[cell.program_counter]
  advance_program_counter(cell)

  case command.type
  when Command::SPLIT
    existing_cell = cell_at_relative_location(world, cell.row, cell.col, command.parameters[0])
    return unless existing_cell.nil?
    row, col = relative_location(cell.row, cell.col, command.parameters[0])
    new_cell = Cell.new(row, col)
    new_cell.parent = cell
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
      move_past_inactive_commands(other_cell)
    end
  when Command::DIE
    world.grid[cell.row][cell.col] = nil
    world.cells.delete(cell)
  when Command::SENSE_CELL
    other_cell = cell_at_relative_location(world, cell.row, cell.col, command.parameters[0])
    cell.register = !(other_cell.nil?)
  when Command::JUMP_IF_TRUE
    if cell.register
      jump_cell(cell, command.parameters[0])
    end
  when Command::LABEL
    return if no_active_commands?(cell)
    advance_program_counter(cell)
    simulate_cell_cycle(world, cell)
  when Command::SLEEP
    # Do nothing
  when Command::JUMP
    jump_cell(cell, command.parameters[0])
  when Command::ACTIVATE
    other_cell = cell_at_relative_location(world, cell.row, cell.col, command.parameters[0])
    unless other_cell.nil?
      other_cell.commands.each_with_index do |other_command, i|
        if other_command.color == command.parameters[1]
          other_command.active = true
        end
      end
    end
  else
    raise "unknown command #{command.type}"
  end
end

def no_active_commands?(cell)
  cell.commands.all? do |command|
    !command.active || command.type == Command::LABEL
  end
end

def advance_program_counter(cell)
  return if no_active_commands?(cell)
  cell.program_counter += 1
  cell.program_counter %= cell.commands.length
  move_past_inactive_commands(cell)
end

def move_past_inactive_commands(cell)
  return if no_active_commands?(cell)
  while !cell.commands[cell.program_counter].active || cell.commands[cell.program_counter].type == Command::LABEL
    cell.program_counter += 1
    cell.program_counter %= cell.commands.length
  end
end

def jump_cell(cell, label)
  cell.commands.each_with_index do |command, i|
    if command.type == Command::LABEL && command.parameters[0] == label
      cell.program_counter = i
      advance_program_counter(cell)
      return
    end
  end
  raise "Unknown label #{label}"
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

COLOR_MAP = {
  '-' => Command::NONE,
  'R' => Command::RED,
  'B' => Command::BLUE,
  'Y' => Command::YELLOW,
  'G' => Command::GREEN,
  'P' => Command::PURPLE,
  'O' => Command::ORANGE,
}

COMMAND_MAP = {
  'SPLIT' => Command::SPLIT,
  'SUPPRESS' => Command::SUPPRESS,
  'DIE' => Command::DIE,
  'SENSE_CELL' => Command::SENSE_CELL,
  'JUMP_IF_TRUE' => Command::JUMP_IF_TRUE,
  'LABEL' => Command::LABEL,
  'SLEEP' => Command::SLEEP,
  'JUMP' => Command::JUMP,
  'ACTIVATE' => Command::ACTIVATE,
}

ARGUMENT_MAP = {
  'UP' => Command::UP,
  'DOWN' => Command::DOWN,
  'RIGHT' => Command::RIGHT,
  'LEFT' => Command::LEFT,
  'SELF' => Command::SELF,
}.merge(COLOR_MAP)

def cell_from_file(program_path)
  lines = File.read(program_path).split("\n")
  commands = lines.reject do |line|
    line.strip.length == 0
  end.map do |line|
    parts = line.split(" ")
    color = COLOR_MAP[parts[0]]
    raise "unknown color #{parts[0]}" if color.nil?
    command_type = COMMAND_MAP[parts[1]]
    raise "unknown command #{parts[1]}" if command_type.nil?
    arguments = parts.drop(2)
    if command_type != Command::LABEL && command_type != Command::JUMP_IF_TRUE && command_type != Command::JUMP
      arguments = arguments.map do |s|
        a = ARGUMENT_MAP[s]
        if a.nil?
          raise "Unable to parse #{s}"
        end
        a
      end
    end
    Command.new(command_type, arguments, color)
  end

  cell = Cell.new(4, 4)
  cell.commands = commands

  cell
end

def target_from_file(target_path)
  lines = File.read(target_path).split("\n")
  lines.map do |line|
    line.split(" ").map do |spot|
      if spot == ".."
        false
      elsif spot == "XX"
        true
      else
        raise "Unknown symbol #{spot}"
      end
    end
  end
end

def simulate(zygote, target, log1, log2)
  world = World.new(zygote: zygote)
  cycles_elapsed = 0
  differences = -1
  cycles_with_zero_differences = 0
  stable = false
  100.times do |i|
    simulate_world_cycle(world)
    print_world(world, log1, log2)
    cycles_elapsed += 1
    differences = count_differences(target, world.grid)
    if differences == 0
      cycles_with_zero_differences += 1
    else
      cycles_with_zero_differences = 0
    end
    if cycles_with_zero_differences == 10
      stable = true
      break
    end
  end
  log1.write("\n\n")
  log2.write("\n\n")

  [world, differences, stable, cycles_elapsed]
end

def print_target(target)
  result = target.map do |row|
    row.map do |val|
      if val
        "XX"
      else
        ".."
      end
    end.join(" ")
  end.join("\n")

  puts result
end

def count_differences(target, actual)
  differences = 0
  target.each_with_index do |row, i|
    row.each_with_index do |target_val, j|
      if !(actual[i][j].nil?) != target_val
        differences += 1
      end
    end
  end

  differences
end
