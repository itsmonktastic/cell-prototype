class Enum
  attr_accessor :string_name
  def initialize(string_name)
    self.string_name = string_name
  end

  def to_s
    self.string_name
  end
end

class OpCode < Enum
  ACTIVATE = new('ACTIVATE')
  DIE = new('DIE')
  JUMP = new('JUMP')
  JUMP_IF_TRUE = new('JUMP_IF_TRUE')
  LABEL = new('LABEL')
  SENSE_CELL = new('SENSE_CELL')
  SLEEP = new('SLEEP')
  SPLIT = new('SPLIT')
  SUPPRESS = new('SUPPRESS')
end

class Direction < Enum
  DOWN = new('DOWN')
  LEFT = new('LEFT')
  RIGHT = new('RIGHT')
  SELF = new('SELF')
  UP = new('UP')
end

class Color < Enum
  BLUE = new('BLUE')
  GREEN = new('GREEN')
  NONE = new('NONE')
  ORANGE = new('ORANGE')
  PURPLE = new('PURPLE')
  RED = new('RED')
  YELLOW = new('YELLOW')
end

class Command
  PARAMETERS = {
    OpCode::ACTIVATE => [Direction, Color],
    OpCode::DIE => [],
    OpCode::JUMP => [String],
    OpCode::JUMP_IF_TRUE => [String],
    OpCode::LABEL => [String],
    OpCode::SENSE_CELL => [Direction],
    OpCode::SLEEP => [],
    OpCode::SPLIT => [Direction],
    OpCode::SUPPRESS => [Direction, Color],
  }

  attr_accessor :opcode, :parameters, :color, :active

  def initialize(opcode:, parameters: [], color: Color::NONE)
    self.opcode = opcode
    self.color = color
    self.active = true
    
    if parameters.length != PARAMETERS[opcode].length
      raise "Expected #{PARAMETERS[opcode].length} parameters, got #{parameters.length}, for #{opcode}"
    end

    PARAMETERS[opcode].each_with_index do |param_type, i|
      unless parameters[i].kind_of?(param_type)
        raise "Expected a #{param_type} for command #{opcode} but got a #{parameters[i].class} at position #{i}"
      end
    end

    self.parameters = parameters
  end

  def to_s
    s = "#{self.opcode}"
    if self.parameters.length > 0
      s += "(#{self.parameters.join(", ")})"
    end
    s
  end

  def short_color
    self.color.to_s[0]
  end
end

class Cell
  attr_accessor :commands, :id, :program_counter, :is_new, :is_dead, :row, :col, :register, :parent

  def initialize(commands:, parent:)
    self.commands = commands
    self.parent = parent

    self.program_counter = 0
    self.is_new = true
    self.is_dead = false
    self.register = false
  end

  def pretty_id
    sprintf("%02d", self.id)
  end

  def pretty_register
    self.register ? '1' : '0'
  end
end

class Simulation
  attr_accessor :grid , :next_cell_id, :cells
  attr_reader :num_rows, :num_cols

  DEFAULT_GRID_SIZE = 9

  def initialize(program_commands:, num_rows: DEFAULT_GRID_SIZE, num_cols: DEFAULT_GRID_SIZE)
    zygote = Cell.new(
      commands: program_commands,
      parent: nil,
    )
    @num_rows = num_rows
    @num_cols = num_cols
    self.grid = Array.new(num_rows) { Array.new(num_cols) }
    self.next_cell_id = 0
    self.cells = []

    self.add_cell(cell: zygote, row: num_rows/2, col: num_cols/2)
  end

  def add_cell(cell:, row:, col:)
    if row < 0 || row >= num_rows || col < 0 || col >= num_cols
      raise "(#{row}, #{col}) is off the grid"
    end
    raise "(#{row}, #{col}) is not empty" unless self.grid[row][col].nil?

    self.grid[row][col] = cell
    cell.row = row
    cell.col = col
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

def print_simulation(simulation, log, long_log)
  print_grid(simulation.grid, log)
  print_grid(simulation.grid, long_log)

  log.write("\n")

  simulation.cells.each do |cell|
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
      log.write("#{command.short_color} ")
    end
    if cell.program_counter == i
      log.write("-> ")
    else
      log.write("   ")
    end
    log.write(command.to_s)

    log.write("\n")
  end
end

def simulate_cell_cycle(simulation, cell)
  return if cell.is_new || no_active_commands?(cell)
  move_past_inactive_commands(cell)
  command = cell.commands[cell.program_counter]
  advance_program_counter(cell)

  case command.opcode
  when OpCode::SPLIT
    row, col = relative_location(cell.row, cell.col, command.parameters[0])
    if space_empty?(simulation, row, col)
      new_cell = cell = Cell.new(
        commands: cell.commands.map(&:dup),
        parent: cell,
      )
      simulation.add_cell(cell: new_cell, row: row, col: col)
    end
  when OpCode::SUPPRESS
    other_cell = cell_at_relative_location(simulation, cell.row, cell.col, command.parameters[0])
    unless other_cell.nil?
      other_cell.commands.each_with_index do |other_command, i|
        if other_command.color == command.parameters[1]
          other_command.active = false
        end
      end
      move_past_inactive_commands(other_cell)
    end
  when OpCode::DIE
    simulation.grid[cell.row][cell.col] = nil
    cell.is_dead = true
  when OpCode::SENSE_CELL
    other_cell = cell_at_relative_location(simulation, cell.row, cell.col, command.parameters[0])
    cell.register = !(other_cell.nil?)
  when OpCode::JUMP_IF_TRUE
    if cell.register
      jump_cell(cell, command.parameters[0])
    end
  when OpCode::LABEL
    return if no_active_commands?(cell)
    advance_program_counter(cell)
    simulate_cell_cycle(simulation, cell)
  when OpCode::SLEEP
    # Do nothing
  when OpCode::JUMP
    jump_cell(cell, command.parameters[0])
  when OpCode::ACTIVATE
    other_cell = cell_at_relative_location(simulation, cell.row, cell.col, command.parameters[0])
    unless other_cell.nil?
      other_cell.commands.each_with_index do |other_command, i|
        if other_command.color == command.parameters[1]
          other_command.active = true
        end
      end
    end
  else
    raise "unknown command #{command.opcode}"
  end
end

def space_empty?(simulation, row, col)
  return false if row < 0
  return false if row >= simulation.num_rows
  return false if col < 0
  return false if col >= simulation.num_cols

  simulation.grid[row][col].nil?
end

def no_active_commands?(cell)
  cell.commands.all? do |command|
    !command.active || command.opcode == OpCode::LABEL
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
  while !cell.commands[cell.program_counter].active || cell.commands[cell.program_counter].opcode == OpCode::LABEL
    cell.program_counter += 1
    cell.program_counter %= cell.commands.length
  end
end

def jump_cell(cell, label)
  cell.commands.each_with_index do |command, i|
    if command.opcode == OpCode::LABEL && command.parameters[0] == label
      cell.program_counter = i
      advance_program_counter(cell)
      return
    end
  end
  raise "Unknown label #{label}"
end

def cell_at_relative_location(simulation, row, col, direction)
  new_row, new_col = relative_location(row, col, direction)
  row = simulation.grid[new_row]
  row[new_col] unless row.nil?
end

def relative_location(row, col, direction)
  case direction
  when Direction::UP
    [row-1, col]
  when Direction::RIGHT
    [row, col+1]
  when Direction::DOWN
    [row+1, col]
  when Direction::LEFT
    [row, col-1]
  when Direction::SELF
    [row, col]
  else
    raise "unkown direction #{command.parameters}"
  end
end

def simulate_cycle(simulation)
  simulation.cells.each do |cell|
    simulate_cell_cycle(simulation, cell)
  end
  simulation.grid.each do |cells|
    cells.each do |cell|
      unless cell.nil?
        cell.is_new = false
      end 
    end
  end
  simulation.cells.select do |cell|
    cell.is_dead
  end.each do |cell|
    simulation.cells.delete(cell)
  end
end

COLOR_MAP = {
  '-' => Color::NONE,
  'R' => Color::RED,
  'B' => Color::BLUE,
  'Y' => Color::YELLOW,
  'G' => Color::GREEN,
  'P' => Color::PURPLE,
  'O' => Color::ORANGE,
}

COMMAND_MAP = {
  'SPLIT' => OpCode::SPLIT,
  'SUPPRESS' => OpCode::SUPPRESS,
  'DIE' => OpCode::DIE,
  'SENSE_CELL' => OpCode::SENSE_CELL,
  'JUMP_IF_TRUE' => OpCode::JUMP_IF_TRUE,
  'LABEL' => OpCode::LABEL,
  'SLEEP' => OpCode::SLEEP,
  'JUMP' => OpCode::JUMP,
  'ACTIVATE' => OpCode::ACTIVATE,
}

ARGUMENT_MAP = {
  'UP' => Direction::UP,
  'DOWN' => Direction::DOWN,
  'RIGHT' => Direction::RIGHT,
  'LEFT' => Direction::LEFT,
  'SELF' => Direction::SELF,
}.merge(COLOR_MAP)

def commands_from_file(program_path)
  lines = File.read(program_path).split("\n")
  commands = lines.reject do |line|
    line.strip.length == 0
  end.map do |line|
    parts = line.split(" ")
    color = COLOR_MAP[parts[0]]
    raise "unknown color #{parts[0]}" if color.nil?
    command_type = COMMAND_MAP[parts[1]]
    raise "unknown command #{parts[1]}" if command_type.nil?
    parameters = parts.drop(2)
    if command_type != OpCode::LABEL && command_type != OpCode::JUMP_IF_TRUE && command_type != OpCode::JUMP
      parameters = parameters.map do |s|
        a = ARGUMENT_MAP[s]
        if a.nil?
          raise "Unable to parse #{s}"
        end
        a
      end
    end
    Command.new(
      opcode: command_type,
      parameters: parameters,
      color: color,
    )
  end
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

def simulate(program_commands, target, log1, log2)
  simulation = Simulation.new(program_commands: program_commands)
  cycles_elapsed = 0
  differences = -1
  cycles_with_zero_differences = 0
  stable = false
  100.times do |i|
    simulate_cycle(simulation)
    print_simulation(simulation, log1, log2)
    cycles_elapsed += 1
    differences = count_differences(target, simulation.grid)
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

  [simulation, differences, stable, cycles_elapsed]
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

def challenge_path(challenge)
  "challenges/#{challenge}"
end

def list_challenges
  Dir.entries("challenges").reject { |e| e[0] == '.' }
end

def list_programs(challenge)
  Dir.entries("#{challenge_path(challenge)}")
    .reject { |e| e[0] == '.' }
    .select { |e| File.directory?("#{challenge_path(challenge)}/#{e}") }
end

def leaderboard_path(challenge)
  "#{challenge_path(challenge)}/leaderboard.txt"
end

def parse_leaderboard(challenge)
  path = leaderboard_path(challenge)
  FileUtils.touch(path)
  lines = File.read(path).split("\n")
  Hash[lines.map { |line| deserialize_leaderboard_row(line) }]
end

def sort_leaderboard(leaderboard)
  leaderboard.entries.sort_by do |program, row|
    serialize_leaderboard_row(row)
  end
end

def serialize_leaderboard_row(row)
  "#{row[:differences]} #{row[:stable] ? '+' : '-'} #{row[:cycles]} #{row[:commands]}"
end

def deserialize_leaderboard_row(row)
  parts = row.split(" ")
  [parts[0], {
    differences: parts[1].to_i,
    stable: parts[2] == '+',
    cycles: parts[3].to_i,
    commands: parts[4].to_i
  }]
end

def save_leaderboard(challenge, leaderboard)
  path = leaderboard_path(challenge)
  data = sort_leaderboard(leaderboard).map do |program, row|
    "#{program} #{serialize_leaderboard_row(row)}"
  end.join("\n")
  File.write(path, data)
end

def update_leaderboard(challenge, program, differences, stable, cycles)
  leaderboard = parse_leaderboard(challenge)
  leaderboard[program] = {
    differences: differences,
    stable: stable,
    cycles: cycles,
    commands: commands_from_file(program_path(challenge, program)).length,
  }
  save_leaderboard(challenge, leaderboard)
end

def program_path(challenge, program)
  "#{challenge_path(challenge)}/#{program}/#{program}.cell"
end

def print_leaderboard(challenge, you=nil)
  leaderboard = parse_leaderboard(challenge)
  rows = sort_leaderboard(leaderboard).map do |program, value|
    if program == you
      prefix = "* "
    else
      prefix = "  "
    end
    [prefix + program_path(challenge, program), value[:differences], value[:stable], value[:commands], value[:cycles]]
  end
  table = Terminal::Table.new(
    headings: ["Solution", "Errors", "Stable?", "# Commands", "# Cycles"],
    rows: rows,
  )
  puts "LEADERBOARD"
  puts table
end

def current_user
  ask_for_username unless File.file?('.user')
  File.read('.user').strip
end

def ask_for_username
  puts "Please enter a username:"
  username = STDIN.readline
  File.write(".user", username)
  puts "Saved username in `.user`"
end
