# implement named save games
# let player input size


require 'byebug'
require 'yaml'

class Tile
  attr_accessor :value, :bomb, :row, :col

  def initialize(row, col, value)
    @row = row
    @col = col
    @value = value
  end

  def bomb?
    @bomb
  end

  def flagged?
    @value == 'F'
  end

  def revealed?
    !['*', 'F'].include?(@value)
  end

end

class Board
  CORNER_DIFF = [
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1]
  ]

  NEAR_DIFF = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1]
  ]

  attr_reader :board, :size

  def initialize(size)
    @size = size
    set_tiles
    seed_board
  end

  def near_neighbors(tile)
    n = []

    NEAR_DIFF.each do |diff|
      new_row = diff[0] + tile.row
      new_col = diff[1] + tile.col
      if (0...@size).include?(new_row) && (0...@size).include?(new_col)
        n << @board[new_row][new_col]
      end
    end

    n
  end

  def all_neighbors(tile)
    n = []

    (NEAR_DIFF + CORNER_DIFF).each do |diff|
      new_row = diff[0] + tile.row
      new_col = diff[1] + tile.col
      if (0...@size).include?(new_row) && (0...@size).include?(new_col)
        n << @board[new_row][new_col]
      end
    end

    n
  end

  def num_bomb_neighbors(tile)
    num = 0

    all_neighbors(tile).each do |neighbor|
      num += 1 if neighbor.bomb?
    end

    num
  end

  def reveal(tile)
    bomb_neighbors = num_bomb_neighbors(tile)

    if bomb_neighbors > 0
      tile.value = bomb_neighbors
    else
      tile.value = '_'
    end
  end

  def render
    puts board_to_s
  end

  private

  def set_tiles
    @board = Array.new(@size) { Array.new(@size) }

    @size.times do |row|
      @size.times do |col|
        @board[row][col] = Tile.new(row, col, '*')
      end
    end
  end

  def seed_board
    num_bombs = (@size ** 2) / 10
    i = 0

    until i == num_bombs
      row = rand(@size)
      col = rand(@size)

      i += 1 unless @board[row][col].bomb?
      @board[row][col].bomb = true
    end
  end

  # will not be so pretty if @size > 9
  def board_to_s
    output = '    ' + (1..@size).to_a.join(' ') + "\n\n"

    @board.each_with_index do |row, i|
      output << (i + 1).to_s + '   '
      row.each do |tile|
        output << tile.value.to_s + " "
      end
      output << "\n"
    end

    output
  end


end


class Game

  def initialize(options)
    @size = options[:size] || 9
    @board = Board.new(@size)
    @over = false
  end

  def play
    loop do
      @board.render

      pos = get_pos

      return if pos == 'q'
      if pos == 'l'
        self.class.load.play
      end
      if pos == 's'
        save
        puts "game saved!"
        next
      end
      tile = @board.board[pos[0]][pos[1]]
      move = get_move

      do_move(tile, move)
      return if @over
    end
  end

  def do_move(tile, move)
    if move == 'f'
      flag(tile)
    else
      if tile.bomb?
        lose
        @over = true
      else
        reveal_chain(tile)
        if won?
          win
          @over = true
        end
      end
    end
  end

  def lose
    puts "You are a loser!!"
    reveal_all
    @board.render
  end

  def won?
    won = true

    @board.board.each do |row|
      row.each do |tile|
        won = false if !tile.bomb? && tile.flagged?
        won = false if tile.value == '*'
      end
    end

    won
  end

  def win
    puts "You are a winner!!!"
    reveal_all
    @board.render
  end

  def get_pos
    pos = nil

    until pos
      puts "(s to save, q to quit, l to load)"
      puts "pick a tile by row col (e.g 1 2)"
      pos = gets.chomp.split(' ')

      return pos.first if ['s', 'q', 'l'].include?(pos.first)
      row = pos[0].to_i - 1
      col = pos[1].to_i - 1

      if @board.board[row][col].revealed?
        pos = nil
        puts "tile already revealed"
      end

      unless (0...@size).include?(row) && (0...@size).include?(col)
        puts "input unparsable or out of bounds"
        pos = nil
      end
    end

    [row, col]
  end

  def get_move
    move = nil

    until ['r', 'f'].include?(move)
      puts "reveal or flag? (r/f)"
      move = gets.chomp
    end

    move
  end

  def reveal_chain(tile)
    return if tile.value == '_'
    @board.reveal(tile)

    if tile.value == '_'
      @board.near_neighbors(tile).each do |neighbor|
        reveal_chain(neighbor)
      end
    end
  end

  def flag(tile)
    if ['*', 'F'].include?(tile.value)
      tile.value = (tile.flagged? ? '*' : 'F')
    else
      puts "You can't flag a tile that's already revealed"
    end
  end

  def reveal_all
    @board.board.each do |row|
      row.each do |tile|
        if tile.bomb?
          tile.value = "B"
        elsif @board.num_bomb_neighbors(tile) > 0
          tile.value = @board.num_bomb_neighbors(tile)
        else
          tile.value = "_"
        end
      end
    end
  end

  def save
    File.open("minesweeper.yml", "w") do |f|
      f << self.to_yaml
    end
  end

  def self.load(file_name = 'minesweeper.yml')
    f = File.read(file_name)
    YAML::load(f)
  end

end

if __FILE__ == $PROGRAM_NAME
  puts 'enter saved game file name if desired'
  file_name = gets.chomp
  if file_name != ''
    game = Game.load(file_name)
  else
    game = Game.new(size: 9)
  end

  game.play
end
