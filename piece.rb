require 'Qt'

NUM_COLORS = 4
$colors = [Qt::Color.new(200,0,0),   #red
           Qt::Color.new(0,170,50),  #green
           Qt::Color.new(180,180,0), #yellow
           Qt::Color.new(0,0,200)   #blue
          ]
$colors_bright = [Qt::Color.new(255,100,100),   #red
                     #Qt::Color.new(100,255,135),  #green
                     Qt::Color.new(40,195,85),  #green
                     #Qt::Color.new(255,255,0), #yellow
                     Qt::Color.new(200,200,0), #yellow
                     #Qt::Color.new(0,0,255),   #blue
                     Qt::Color.new(100,100,255),   #blue
                    ]
$colors_bright_highlight = [Qt::Color.new(235,160,160),   #red
                     Qt::Color.new(135,255,165),  #green
                     Qt::Color.new(255,255,255), #yellow
                     Qt::Color.new(160,160,235),   #blue
                    ]                    
module Bouncy_ball
  def self.extended base
    base.init_vars  
  end
  def init_vars
      g = Qt::RadialGradient.new 3*(width/4)-5,height/4 +5, width*0.6
      g.setColorAt(0,$colors_bright[color])
      g.setColorAt(0.3,$colors[color])      
      g.setColorAt(1, Qt::Color.new(Qt::black))
      @regular_brush = Qt::Brush.new(g)
      
      @shine_spot = [[3*(width/4)-1, height/4 + height/7],
                   [3*(width/4)  , height/4 + height/7],
                   [3*(width/4)+1, height/4 + height/7+1],
                   [3*(width/4)+1, height/4 + height/7+2],
                   [3*(width/4)  , height/4 + height/7+3],
                   [3*(width/4)-1, height/4 + height/7+3],
                   [3*(width/4)-2, height/4 + height/7+2],
                   [3*(width/4)-2, height/4 + height/7+1]]
     @locations = [[3,2],[4,3],[4,4],[3,5],
                  [2,5],[1,4],[1,3],[2,2]]
    @highlight_brushes = []    
    @shine_spot.each_with_index do |spot,i|
      g = Qt::RadialGradient.new spot[0],spot[1],width*0.6
      g.setColorAt(0,$colors_bright_highlight[@color])
      g.setColorAt(0.4,$colors[@color])    
      g.setColorAt(1, Qt::Color.new(Qt::black))
      @highlight_brushes << Qt::Brush.new(g)      
    end
    @frame = 0 
    @loc_offset = rand(8)
    @loc_frame = @loc_offset                  
  end
  def paintEvent event      
    painter = Qt::Painter.new self   
    if @highlighted          
      painter.setPen(Qt::NoPen)
      painter.setBrush(@highlight_brushes[@frame])      
      painter.drawEllipse(@locations[@loc_frame][0], @locations[@loc_frame][1],@width-5, @height-5)
    else           
      painter.setBrush(@regular_brush)      
      painter.setPen(Qt::NoPen)
      painter.drawEllipse(5, 5,@width-10, @height-10)           
    end  
    painter.end  
  end
  def advance
    @frame += 1    
    @frame %= @shine_spot.length
    @loc_frame += 1
    @loc_frame %= @locations.length
    update
  end
end

module Square_tile
  def self.extended base
    base.init_vars
  end
  def init_vars    
    @regular_brush = Qt::Brush.new($colors[@color])
    @hightlight_brush = Qt::Brush.new($colors_bright[@color])  
  end
  def paintEvent event 
    painter = Qt::Painter.new self
    if @highlighted      
      b = Qt::Brush.new($colors_bright_highlight[@color])
      highlight_pen = Qt::Pen.new(b,2,Qt::SolidLine)
      painter.setPen highlight_pen
      painter.drawRect 2,2,@width-4,@height-4
      painter.fillRect 3,3,@width-6,@height-6,@hightlight_brush      
    else      
      painter.setPen Qt::NoPen
      painter.fillRect 1,1,@width-2,@height-2, @regular_brush
    end
    painter.end
  end
end

module Star_tile
  def self.extended base
    base.init_vars
  end
  @@regular_polygon = nil
  @@highlight_polygons = nil
  @@star_width = nil
  @@star_height = nil
  def get_base_points width,height
    sbw = 10 #star branch width
    points = [[width/2,5],
              [(width/2)-sbw+2,height/3],
              [5,height/3+3],
              [width/3-2,height/3 + sbw+5],
              [14,height-9],
              [width/2, 2*height/3+4],
              [width-14,height-9],
              [2*width/3+1,height/3+sbw+5],
              [width-5, height/3+3],
              [width/2 + sbw-2,height/3]
              ]
     return points
  end

  def get_polygons width, height
    if @@highlight_polygons.nil? or @@star_width != width or @@star_height != height
      @@star_width = width
      @@star_height = height      
      points = get_base_points width, height
      @@regular_polygon = Qt::Polygon.new points.length    
      points.each_with_index do |p,i|         
        @@regular_polygon.setPoint(i, Qt::Point.new(p[0],p[1]))
      end
      
      @@star_width = width
      @@star_height = height
      points = get_base_points width, height
      @@highlight_polygons = [@@regular_polygon]
      7.times do
        hpoints = points.dup
        hpoints[1][0] += 1
        hpoints[2][0] += 4
        hpoints[3][0] += 2
        hpoints[4][0] += 3
        hpoints[6][0] -= 3
        hpoints[7][0] -= 2
        hpoints[8][0] -= 4
        hpoints[9][0] -= 1
        h_polygon = Qt::Polygon.new hpoints.length    
        hpoints.each_with_index do |p,i|         
          h_polygon.setPoint(i, Qt::Point.new(p[0],p[1]))
        end
        @@highlight_polygons << h_polygon  
      end
      tmp = @@highlight_polygons.dup
      tmp.shift
      tmp.reverse!
      @@highlight_polygons << tmp
      @@highlight_polygons.flatten!
    end
    return @@regular_polygon, @@highlight_polygons
  end

  def init_vars    
    @regular_brush = Qt::Brush.new($colors[@color])
    @hightlight_brush = Qt::Brush.new($colors_bright[@color])
    @frame = 0       
    @regular_polygon, @highlight_polygons = get_polygons @width, @height
    #@highlight_polygons = get_highlight_polygons @width, @height
           
    b = Qt::Brush.new($colors_bright[@color])
    @regular_pen = Qt::Pen.new(b,4,Qt::SolidLine)
    
    g = Qt::RadialGradient.new 3*(width/4)-5,height/4 +5, width*0.6
    g.setColorAt(0,$colors_bright_highlight[@color])
    g.setColorAt(0.4,$colors[@color])    
    g.setColorAt(1, Qt::Color.new(Qt::black))
    @grad_brush = Qt::Brush.new(g)
  end
  def paintEvent event 
    painter = Qt::Painter.new self
    painter.setPen @regular_pen
    painter.setBrush @grad_brush    
    if @highlighted
      painter.drawPolygon @highlight_polygons[@frame]      
    else
      painter.drawPolygon @regular_polygon
    end
    painter.end
  end
  def advance
    @frame += 1    
    @frame %= @highlight_polygons.length   
    update
  end
end

class Piece < Qt::Widget  
  attr_accessor :x,:y,:color,:highlighted,:width,:height
  attr_accessor :y_vel,:py,:falling
  def initialize parent, size, x, y, type, color = nil
    super parent
    setMouseTracking true
    @x = x #position of piece on the grid
    @y = y
    @width = size.width
    @height = size.height
    resize(@width,@height)
    @color = rand(NUM_COLORS) # index into colors array
    unless color.nil? #for testing
      @color = color
    end
    @highlighted = false
   
    # variables for physics, pixel-x, pixel-y
    @px, @py, @y_vel,@y_accel = 0,0,0,0
    @falling = false

    case type
      when :bouncy_balls
        extend Bouncy_ball
      when :squares
        extend Square_tile
      when :stars
        extend Star_tile
    end
  end 
  def advance    
  end
  def highlight
    @highlighted = true
  end
  def dehighlight
    @highlighted = false
    @frame = 0
    @loc_frame = @loc_offset
  end
end