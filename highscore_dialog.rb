require 'Qt'

class HighScoreDialog < Qt::Dialog
  def initialize parent, high_scores
    super parent
  
    setWindowTitle "High Scores"
    resize(parent.width*4/5,parent.height/2)
    large_group = Qt::GroupBox.new "Big - 20x15" do
      setPalette(Qt::Palette.new( Qt::Color.new(110,120,120)))
      setAutoFillBackground(true)      
      vl = Qt::VBoxLayout.new
      scores = high_scores[:large].sort{ |a,b| b[1]<=>a[1] }
      scores.each do |val|
        name = val[0]
        label = Qt::Label.new( "#{val[1].to_s} - #{name}")
        vl.addWidget label            
      end
      vl.addStretch
      setLayout vl
    end
    medium_group = Qt::GroupBox.new "Medium - 15x10" do
      setPalette(Qt::Palette.new( Qt::Color.new(110,120,120)))
      setAutoFillBackground(true)
      vl = Qt::VBoxLayout.new          
      scores = high_scores[:medium].sort{ |a,b| b[1]<=>a[1] }
      scores.each do |val|
        name = val[0]
        label = Qt::Label.new( "#{val[1].to_s} - #{name}")
        vl.addWidget label            
      end
      vl.addStretch
      setLayout vl
    end
    small_group = Qt::GroupBox.new "Little - 8x5" do
      setPalette(Qt::Palette.new( Qt::Color.new(110,120,120)))
      setAutoFillBackground(true)
      vl = Qt::VBoxLayout.new
      scores = high_scores[:small].sort{ |a,b| b[1]<=>a[1] }
      scores.each do |val|
        name = val[0]
        label = Qt::Label.new( "#{val[1].to_s} - #{name}")
        vl.addWidget label
      end
      vl.addStretch
      setLayout vl
    end
    done_pb = Qt::PushButton.new "Done"
    done_pb.setDefault true
    done_pb.connect(SIGNAL :clicked) { accept }
    vlayout = Qt::VBoxLayout.new do
      scores_hl = Qt::HBoxLayout.new do
        addWidget large_group
        addWidget medium_group
        addWidget small_group
      end
      addLayout scores_hl
      hl = Qt::HBoxLayout.new
      hl.addStretch
      hl.addWidget done_pb
      addLayout hl
    end
    setLayout vlayout
  end
end