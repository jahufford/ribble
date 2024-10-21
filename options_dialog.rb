require 'Qt'

class Hash
  def to_variant
    RubyVariant.new RubyVariant::MyHash.new(self)
  end
end

class OptionsDialog < Qt::Dialog
  signals 'options_changed(QVariant)'
  def initialize parent, cur_options
    #options are the current options
    super parent
    options = cur_options.dup
    setWindowTitle "Options"
                
    size_group = Qt::GroupBox.new "Gameboard Size" do
      sizes = [:small,:medium,:large]
      sizes_rb = {}          
      sizes_rb[:small] = Qt::RadioButton.new("Little - 8x5")  # piece size 65x65      
      sizes_rb[:medium] = Qt::RadioButton.new("Medium - 15x10") # 65x65
      sizes_rb[:large] = Qt::RadioButton.new("Big - 20x15")  # 50x50
      sizes.each do |sym|
        sizes_rb[sym].connect(SIGNAL :clicked){
          options[:size] = sym
        }
      end
      vl = Qt::VBoxLayout.new do
        sizes.each do |sym|
          addWidget sizes_rb[sym]
        end        
        sizes_rb[cur_options[:size]].setChecked true
      end
      setLayout vl
    end
    
    pieces_group = Qt::GroupBox.new "Piece Style" do
      piece_types = [:bouncy_balls, :squares, :stars]
      pieces_rb = {}
      pieces_rb[:bouncy_balls] = Qt::RadioButton.new("Bouncy Balls")
      pieces_rb[:squares] = Qt::RadioButton.new("Squares")
      pieces_rb[:stars] = Qt::RadioButton.new("Spinning Stars")
      piece_types.each do |sym|
        pieces_rb[sym].connect(SIGNAL :clicked){
          options[:piece_type] = sym
        }
      end
      vl = Qt::VBoxLayout.new do
        piece_types.each do |sym|
          addWidget pieces_rb[sym]
        end
        pieces_rb[cur_options[:piece_type]].setChecked true
      end
      setLayout vl
    end
    
    gamemode_group = Qt::GroupBox.new "Game Mode" do
      gamemode_rb = {}
      gamemode_rb[:classic] = Qt::RadioButton.new("Classic - Clear the board")
      gamemode_rb[:continuous] = Qt::RadioButton.new("Continuous - New rows fall faster with each level")
      [:classic,:continuous].each do |sym|
        gamemode_rb[sym].connect(SIGNAL :clicked){
          options[:mode] = sym
        }
      end
      vl = Qt::VBoxLayout.new
      vl.addWidget gamemode_rb[:classic]
      vl.addWidget gamemode_rb[:continuous]
      gamemode_rb[options[:mode]].setChecked true
      setLayout vl
    end
    cancel_pb = Qt::PushButton.new("Cancel")
    cancel_pb.connect(SIGNAL("clicked()")){
      reject
    }
    ok_pb = Qt::PushButton.new("Ok")
    ok_pb.setDefault(true)
    ok_pb.connect(SIGNAL("clicked()")){
      unless options == cur_options
        opt = options.to_variant
        emit options_changed opt
      end
      accept
    }
    hlayout = Qt::HBoxLayout.new do
      addStretch
      addWidget cancel_pb
      addWidget ok_pb
    end
    vlayout = Qt::VBoxLayout.new do
      addWidget size_group
      addWidget pieces_group
      addWidget gamemode_group
      addStretch
      addLayout hlayout
    end        
    setLayout vlayout   
  end
end