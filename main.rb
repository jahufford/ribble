#!/usr/bin/env ruby
require 'Qt'

# class RubyVariant < Qt::Variant
  # attr_accessor :value
  # def initialize value
    # super
    # @value = value
  # end  
# end
require './gameboard.rb'
require './options_dialog.rb'
require './highscore_dialog.rb'
GAMEBOARD_WIDTH = 8
GAMEBOARD_HEIGHT = 5

class RubyVariant < Qt::Variant
  # all these shenanigans is necessary to be able to emit
  # a hash from a signal. You can emit a ruby class by wrapping it in
  # a QVariant, but the built in ruby hash won't work with this, it needs
  # to be wrapped inside another class  
  def initialize value
    super()
    @value = value
  end
  def value
    @value.value
  end
  class MyHash
    attr_accessor :value
    def initialize value
      @value = value
    end
  end
end

class MainWindow < Qt::MainWindow
  slots 'moveMove(int,int)'
  def initialize
    super
    resize(750,800)    
    setWindowTitle "Ribble"
    $status_bar = statusBar
    statusBar.show()
    
    @previous_game_score = nil
    @status_label = Qt::Label.new("tempmsg")
    statusBar.addPermanentWidget @status_label
    
    setup_menubar

    #load options and high scores
    @filename = "ribble.dat"   
    @high_scores = { :large=>[],
                     :medium=>[],
                     :small=>[]}
    @options = {:mode=>:classic,:size=>:medium,:piece_type=>:bouncy_balls}
    if File.exists? @filename
      load_settings_and_scores
    else
      # create file and put initial data
      puts "creating " + @filename + " with " + @options.to_s
      save_settings_and_scores
    end
    @previous_highscore_name = ""
    
    new_game
  end

  def setup_menubar
    quit = Qt::Action.new "&Quit", self

    game = menuBar().addMenu "&Game"
    new_action = Qt::Action.new "&New Game", self
    restart_action = Qt::Action.new "&Restart Game", self    
    options_action = Qt::Action.new "&Options", self
    highscores_action = Qt::Action.new "&High Scores", self
    quit_action = Qt::Action.new "&Quit", self 
    game.addAction new_action
    game.addAction restart_action
    game.addAction options_action
    game.addAction highscores_action
    game.addAction quit_action
        
    new_action.connect(SIGNAL :triggered) do
      @gameboard = nil      
      new_game
    end
    restart_action.connect(SIGNAL :triggered) do
      @gameboard = nil
      new_game @seed
    end
    options_action.connect(SIGNAL :triggered) do
      options_dialog = OptionsDialog.new self, @options
      options_dialog.connect(SIGNAL('options_changed(QVariant)')) do |opt|
        @options = opt.value
        save_settings_and_scores
        new_game
      end
      options_dialog.exec      
    end
    highscores_action.connect(SIGNAL :triggered) do
      HighScoreDialog.new(self, @high_scores).exec      
    end
    quit_action.connect(SIGNAL :triggered) do
      Qt::Application.instance.quit
    end
    
    about = menuBar().addAction "&About"
    about.connect(SIGNAL :triggered) do      
      Qt::MessageBox.information( self, "About","Ribble, a Same Game clone. By Joe Hufford. 2013")
    end
  end
  
  def keyPressEvent event
    if event.key == Qt::Key_R and event.modifiers == Qt::ControlModifier
      new_game @seed
    elsif event.key == Qt::Key_N and event.modifiers == Qt::ControlModifier      
      new_game
    end    
  end
  
  def new_game seed=nil
    #determine board size and piece size
    gbw,gbh,pcs = 8,5,65 if @options[:size] == :small
    gbw,gbh,pcs = 15,10,65 if @options[:size] == :medium
    gbw,gbh,pcs = 20,15,50 if @options[:size] == :large
    if seed.nil?
      @seed = rand 65535      
    end
    @gameboard = Gameboard.new self, gbw, gbh, pcs, @seed, @options[:piece_type] #old gameboard gets gc'd    
    resize(gbw*pcs, gbh*pcs+50)    
    @gameboard.connect(SIGNAL 'highlightedPointsChanged(int)') do |val|
      statusBar.showMessage(val.to_s)
    end
    @gameboard.connect(SIGNAL 'pointsChanged(int)') do |val|
      str = ""
      unless @previous_game_score.nil?
        str = "Previous Game: #{@previous_game_score}   "
      end
      @status_label.setText(str + " Current Game: #{val.to_s}")
    end
    @gameboard.connect(SIGNAL 'done(int,bool)') do |points,cleared|      
      if cleared
        Qt::MessageBox.information( self, "Cleared!","Cleared it baby! 2x bonus!")
        points *= 2
      end
      @previous_game_score = points
      new_score = handle_high_score points      
      if new_score
        HighScoreDialog.new(self, @high_scores).exec                
      end
      ask_new_game = Qt::Dialog.new(self) do
        setWindowTitle "Your score: #{points.to_s}"
        new_game_pb = Qt::PushButton.new "Play New Gameboard"
        new_game_pb.setDefault true
        new_game_pb.connect(SIGNAL :clicked){done(1)}
        repeat_game_pb = Qt::PushButton.new "Play Same Gameboard Again"
        repeat_game_pb.connect(SIGNAL :clicked){done(2)}
        quit_pb = Qt::PushButton.new "Quit"
        quit_pb.connect(SIGNAL :clicked){done(0)}
        vl = Qt::VBoxLayout.new do 
          addWidget new_game_pb
          addWidget repeat_game_pb
          addWidget quit_pb
        end
        setLayout vl       
      end 
      newggame_response = ask_new_game.exec()      
      if newggame_response  == 1
        new_game
      elsif newggame_response == 2
        new_game @seed
      else
        Qt::Application.instance.quit
      end      
    end
    resizeEvent(nil)
    str = ""
    unless @previous_game_score.nil?
      str = "Previous Game: #{@previous_game_score}   "
    end
    @status_label.setText(str + "Current Game: #{@gameboard.points.to_s}")    
    setCentralWidget @gameboard 
  end
  
  def handle_high_score points
    high_scores = @high_scores[@options[:size]].sort{|a,b| b[1]<=>a[1]}
    lower = high_scores.select{|val| val[1]<points} #top 10 scores that are lower than current score
    if (high_scores[0].nil?) or (high_scores.length<10) or (not lower.empty?)
      name = Qt::InputDialog.getText self, "New Top Ten Score", "You scored #{points}\nEnter your name", Qt::LineEdit::Normal, @previous_highscore_name
      @previous_highscore_name = name
      #delete the lowest high score            
      #store new high score
      if high_scores.length == 10
        high_scores.insert(10-lower.length,[name,points])
        high_scores.pop      
      else
        high_scores << [name,points]
      end
      @high_scores[@options[:size]] = high_scores
      save_settings_and_scores
      return true      
    end
    false
  end
  
  def save_settings_and_scores
    File.open @filename,"w" do |f|
      Marshal.dump @options, f
      Marshal.dump @high_scores, f
    end
  end
  
  def load_settings_and_scores
    File.open @filename,"r" do |f|
      @options = Marshal.load f
      @high_scores = Marshal.load f
    end
  end
  
  def resizeEvent(event)
    puts "MainWindow resizeEvent#{width} #{height}"
    @gameboard.window_resize(self.width,self.height-(menuBar.height+statusBar.height))
  end 
end


Qt::Application.new(ARGV) do
  mainwindow = MainWindow.new
  mainwindow.show 
  exec
end
