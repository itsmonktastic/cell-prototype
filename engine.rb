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
  NONE = Color.new('NONE')
  RED = Color.new('RED')
  BLUE = Color.new('BLUE')
  GREEN = Color.new('GREEN')
  YELLOW = Color.new('YELLOW')
  PURPLE = Color.new('PURPLE')

  PARAMETERS = {
    SPLIT => [Direction],
    SEND_SIGNAL => [Direction],
    SENSE_SIGNAL => [Direction],
    SENSE_CELL => [Direction],
    JUMP_IF_EQUAL => [Fixnum],
    SUPPRESS => [Direction, Color],
  }

  attr_accessor :type, :parameters, :color, :active

  def initialize(type, parameters=[], color=NONE)
    self.type = type
    self.color = color
    self.active = true
    
    if parameters.length != PARAMETERS[type].length
      raise "Expected #{PARAMETERS[type].length} parameters, got #{parameters.length}"
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

def print_world(world, log)
  print_grid(world.grid, log)

  log.write("\n")

  world.cells.each do |cell|
    print_cell(cell, log)
  end
end

def print_cell(cell, log)
  log.write(sprintf("%s :\n", cell.pretty_id))
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

COLOR_MAP = {
  '-' => Command::NONE,
}

COMMAND_MAP = {
  'SPLIT' => Command::SPLIT,
}

ARGUMENT_MAP = {
  'UP' => Command::UP,
  'DOWN' => Command::DOWN,
  'RIGHT' => Command::RIGHT,
  'LEFT' => Command::LEFT,
}

def cell_from_file(program_path)
  lines = File.read(program_path).split("\n")
  commands = lines.map do |line|
    parts = line.split(" ")
    color = COLOR_MAP[parts[0]]
    raise "unknown color #{parts[0]}" if color.nil?
    command_type = COMMAND_MAP[parts[1]]
    raise "unknown command #{parts[1]}" if command_type.nil?
    arguments = parts.drop(2).map do |part|
      a = ARGUMENT_MAP[part]
      if a.nil?
        raise "Unable to parse #{part}"
      end
      a
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

def simulate(zygote, target, log)
  world = World.new(zygote: zygote)
  cycles_elapsed = 0
  100.times do |i|
    simulate_world_cycle(world)
    print_world(world, log)
    cycles_elapsed += 1
    differences = count_differences(target, world.grid)
    if differences == 0
      break
    end
  end
  log.write("\n\n")

  [world, cycles_elapsed]
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

def parse_leaderboard(challenge)
  path = "challenges/#{challenge}/leaderboard.txt"
  FileUtils.touch(path)
  lines = File.read(path).split("\n")
  leaderboard = {}
  lines.each do |line|
    parts = line.split(" ")
    leaderboard[parts[0]] = leaderboard[parts[1]]
  end
  leaderboard
end

def save_leaderboard(challenge, leaderboard)
  path = "challenges/#{challenge}/leaderboard.txt"
  data = leaderboard.entries.sort_by do |key, value|
    [value[:differences], value[:cycles]]
  end.map do |key, value|
    "#{key} #{value}"
  end.join("\n")
  File.write(path, data)
end

def update_leaderboard(challenge, program, differences, cycles)
  leaderboard = parse_leaderboard(challenge)
  leaderboard[program] = {differences: differences, cycles: cycles}
  save_leaderboard(challenge, leaderboard)
end
