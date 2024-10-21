require 'Qt'
require './piece.rb'
$gravity = 9.8

FPS = 30
# overloaded Qt functions are camelcase

class Gameboard < Qt::Widget
  slots 'do_physics()','highlight_animation()'
  signals 'mouseMove(int, int)','pointsChanged(int)','highlightedPointsChanged(int)','info(int,int)','done(int,bool)'
  attr_reader :points
  Size = Struct.new(:width,:height)
  Column = Struct.new(:column,:px,:x_vel,:falling)
  def initialize parent, gameboard_width, gameboard_height, piece_size, seed, piece_type
    super(parent)
    setMouseTracking true
    setPalette(Qt::Palette.new( Qt::Color.new(20,30,30)))
    setAutoFillBackground(true)
    setFocus Qt::OtherFocusReason
    @last_mouse_pos = []
    @last_over_piece = [] # last piece the mouse was over
    @points = 0    
    
    @grid_width = gameboard_width
    @grid_height = gameboard_height
    @last_column = @grid_width-1    
    @piece_size = Size.new(piece_size,piece_size)
    @width_px = @piece_size.width*@grid_width
    @height_px = @piece_size.height*@grid_height
    resize(@width_px, @height_px)
    
    
    @grid = []
    @grid_height.times{ @grid << Array.new(@grid_width) } # make 2 dimensional grid, accessed as @grid[y][x]    
    @highlighted_pieces = Array.new
    Kernel.srand(seed)
    #Kernel.srand(235) #for testing, use the same grid    
    generate_grid piece_type
    
    @highlight_timer = Qt::Timer.new self
    @highlight_timer.setInterval(1000/FPS)    
    @highlight_timer.connect(SIGNAL :timeout) do
      @highlighted_pieces.each do |piece|
        piece.advance
      end        
    end

    @falling_pieces = []
    @physics_timer = Qt::Timer.new
    @physics_timer.setInterval(1000/FPS)
    connect(@physics_timer, SIGNAL('timeout()'), self, SLOT('do_physics()'))
    @falling_columns = []
    #@timer = Qt::Time.new timer for testing
    @fall_stop_cnt = 0
    @falling = false
    @falling_sideways = false
    @deleting = false    
  end  
  def below piece
    for i in (piece.y+1)...@grid_height
      next if @grid[i][piece.x].nil?
      return @grid[i][piece.x]
    end
    nil
  end
  def column_to_left col
    (col-1).downto(0) do |i|
      return i if not column_empty? i
    end
    nil
  end
  def do_physics    
    damping = 0.5
    sideways_damping = 0.5
    gravity = 2
    # do the integration
    @falling_pieces.each do |piece|
      next unless piece.falling      
      piece.y_vel += gravity
      piece.py += piece.y_vel
    end
    # do collision detection
    @falling_pieces.each do |piece|
      next unless piece.falling
      y1 = piece.y*piece.height + piece.py
      y2 = y1+piece.height
      # do collision detection
      # can only collide with piece above or below it
      if piece.y_vel > 0 #moving down
        below = below piece # could do caching for some speed up
        if below.nil?  #bottom row there's no pieces below
          if y2 >= @grid_height*@piece_size.height
            piece.py -= y2-(@grid_height*@piece_size.height)
            if piece.y_vel < gravity
              piece.y_vel = 0            
              piece.falling = false
              @fall_stop_cnt += 1
            end
          piece.y_vel *= -1*damping
          end
        elsif y2 > (below.y*below.height+below.py) #collision happened
          piece.py -= y2-(below.y*below.height+below.py)
          if piece.y_vel < gravity and not below.falling
            piece.y_vel = 0
            piece.falling = false
            @fall_stop_cnt += 1
          end          
          piece.y_vel *= -1*damping
        end
      end
    end
   
    #move pieces
    @falling_pieces.each do |piece|
      next unless piece.falling
      x = piece.x*piece.width
      y = piece.y*piece.height + piece.py
      piece.move(x,y)
    end
    
    #do "falling" columns
    @falling_columns.each do |col|
      col.x_vel += gravity
      col.px -= col.x_vel
    end
    
    @falling_columns.each do |col|
      lcolumn = column_to_left col.column
      if lcolumn.nil?
        overlap = col.column*@piece_size.width+col.px
        if col.column*@piece_size.width+col.px < 0 #collision with edge of gameboard          
          col.px -= overlap #overlap negative
          if col.x_vel < gravity
            col.falling = false
          end
          col.x_vel *= -1*sideways_damping
        end
      else
        adjustment = 0
        ind = @falling_columns.index{|col| col.column == lcolumn}
        unless ind.nil?
          adjustment = @falling_columns[ind].px #adjustment is if column to the left is also moving
        end
        lbound = (lcolumn+1)*@piece_size.width + adjustment
        overlap = lbound - (col.column*@piece_size.width+col.px)
        if overlap > 0 #collision happened
          col.px += overlap
          if col.x_vel < gravity
            col.falling = false
          end
          col.x_vel *= -1*sideways_damping
        end
      end
    end
    
    @falling_columns.each do |col|
      x = col.column*@piece_size.width + col.px
      for i in 0...@grid_height
        piece = @grid[i][col.column]
        unless piece.nil?
          piece.move(x, piece.pos.y)
        end
      end
    end

    vert_falling = @falling_pieces.length != @fall_stop_cnt
    horiz_falling = @falling_columns.select{|c| c.falling == true}.length > 0

    if not vert_falling and not horiz_falling
      # update @grid and pieces
      update_grid_after_fall
      
      @physics_timer.stop
      @fall_stop_cnt = 0
      @falling_pieces.clear
      @falling = false
      @falling_sideways = false
      @falling_columns.clear
      
      #highlight pieces under the mouse
      lx = @last_mouse_pos[0]/@piece_size.width
      ly = @last_mouse_pos[1]/@piece_size.height
      last_piece = @grid[ly][lx] unless (ly >= @grid_height) or (lx>=@grid_width)
      dehighlight_pieces
      highlight_pieces last_piece unless last_piece.nil?
      
      if done?
         cleared = @grid.flatten.reject{|spot| spot.nil?}.length == 0
         emit done(@points,cleared)
      end
    end
  end

  def update_grid_after_fall   
    for x in (0...@grid_width)
      (@grid_height-1).downto(1) do |y|
        next unless @grid[y][x].nil?        
        (y-1).downto(0) do |i|
          next if @grid[i][x].nil?          
          @grid[y][x] = @grid[i][x]
          @grid[i][x] = nil
          @grid[y][x].y = y         
          break
        end
      end
    end
     @falling_pieces.each do |piece|
      piece.py = 0
     # piece.move(piece.x*@piece_size.width,piece.y*@piece_size.height)      
    end
    @falling_columns.each do |col|
      for i in 0...@grid_height
        next if @grid[i][col.column].nil?
        piece = @grid[i][col.column]
        @grid[i][col.column] = nil
        piece.x -= (col.px/@piece_size.width).round.abs
        @grid[i][piece.x] = piece
      end
    end
  end
  def grid_check
    for x in (0...@grid_width)
      for y in (0...@grid_height)
        next if @grid[y][x].nil?
        return false if @grid[y][x].x != x or @grid[y][x].y != y
      end
    end
    true
  end
  
  def resizeEvent event
    "puts gb resize"
  end
  
  def keyPressEvent event    
    if event.key == Qt::Key_Z and event.modifiers == Qt::ControlModifier
      puts "undo"
    else
      event.ignore #pass to mainwindow
    end    
  end  
  def paintEvent event
    painter = Qt::Painter.new self    
    draw_background painter
    painter.end
  end
  def leaveEvent event
    unless @deleting #or @falling # this is because when you hide the widgets it genereates a leave event
                     # and clears the @highlighted_pieces array
      # de-hightlight pieces          
      dehighlight_pieces
    end
  end
  def mousePressEvent event
    return if @falling or @falling_sideways 
    delete_and_fall_pieces
    update 
  end
  def mouseMoveEvent event
    # handle the event processing ourselves because their seems to be a glitch in using the
    # qwidget's enter and leave events
    @last_mouse_pos = [event.x,event.y]
    return if @falling or @falling_sideways   
    local_x = event.x/@piece_size.width
    local_y = event.y/@piece_size.height
    return if local_x >= @grid_width or local_y>=@grid_height    
    if (@last_over_piece[0] != local_x) or (@last_over_piece[1] != local_y)
      #equivalent to a leave event
      @last_over_piece = [local_x,local_y]       
      unless @deleting #or @falling # this is because when you hide the widgets it genereates a leave event
                       # and clears the @highlighted_pieces array
        # de-hightlight pieces          
        dehighlight_pieces
      end
      unless @grid[local_y][local_x].nil?
        if not @grid[local_y][local_x].highlighted #don't rerun highlight method if already highlighted
          highlight_pieces @grid[local_y][local_x] # pass the starting piece to it.
        end
      end
    end
  end
  def draw_background painter
    # draw a grid for the background    
    painter.save    
    pen = Qt::Pen.new(Qt::Brush.new(Qt::Color.new 120,120,120),1,Qt::DashLine)
    painter.setPen pen     
    for x in (1...@grid_width)
      painter.drawLine( x*(@piece_size.width), 5, x*(@piece_size.width), @height_px -5)
    end
    for y in (1..@grid_height-1)
      painter.drawLine 5, y*(@piece_size.height), @width_px-5, y*(@piece_size.height)     
    end    
    painter.restore
  end

  def move_widgets
    (0...@grid_width).each do |x|    # next_piece = nil  
      (0...@grid_height).each do |y|
        piece = @grid[y][x]
        unless piece.nil?
          piece.move(x*(piece.width),y*piece.height)         
        end       
      end
    end    
  end

  def window_resize width, height    
    for x in 0...@grid_width
      for y in 0...@grid_height
        unless @grid[y][x].nil?
          @grid[y][x].width = @piece_size.width
          @grid[y][x].height = @piece_size.height
          @grid[y][x].resize(@piece_size.width,@piece_size.height)
        end
      end
    end
    move_widgets
  end
  
  def highlight_pieces piece
    @highlighted_pieces << piece
    piece.highlighted = true
    #recursive flood fill algorithm
    walk piece
    if @highlighted_pieces.length > 1
      @highlighted_pieces.each{ |piece| piece.update }            
      val = (@highlighted_pieces.length-1)**2
      @highlight_timer.start
      emit highlightedPointsChanged(val)
    else
      @highlight_timer.stop
      @highlighted_pieces[0].dehighlight
      @highlighted_pieces.clear
    end
  end
  
  def walk piece
    x = piece.x
    y = piece.y   
    # down   
    unless y+1 == @grid_height or @grid[y+1][x].nil? or @grid[y+1][x].highlighted
      next_piece = @grid[y+1][x]    
      if piece.color == next_piece.color        
        next_piece.highlight 
        @highlighted_pieces << next_piece
        walk next_piece
      end
    end
    # left
    unless x-1 < 0 or @grid[y][x-1].nil? or @grid[y][x-1].highlighted
      next_piece = @grid[y][x-1]
      if piece.color == next_piece.color
        next_piece.highlight
        @highlighted_pieces << next_piece
        walk next_piece
      end
    end
    # up
    unless y-1 < 0 or @grid[y-1][x].nil? or @grid[y-1][x].highlighted
      next_piece = @grid[y-1][x]      
      if piece.color == next_piece.color
        next_piece.highlight
        @highlighted_pieces << next_piece
        walk next_piece
      end
    end
    # right
    unless x+1 == @grid_width or @grid[y][x+1].nil? or @grid[y][x+1].highlighted
      next_piece = @grid[y][x+1]      
      if piece.color == next_piece.color
        next_piece.highlight
        @highlighted_pieces << next_piece
        walk next_piece
      end
    end
  end
      
  def done?
    for x in (0...@grid_width)
      for y in (0...@grid_height)
        unless @grid[y][x].nil?
          unless @grid[y][x+1].nil?
            return false if @grid[y][x].color == @grid[y][x+1].color #right
          end
          next if y == @grid_height-1
          unless @grid[y+1][x].nil?
            return false if @grid[y][x].color == @grid[y+1][x].color #below
          end          
        end        
      end
    end
    return true
  end  

  def dehighlight_pieces
    @highlighted_pieces.each do |piece|
      piece.dehighlight
      piece.update
    end
    @highlight_timer.stop
    @highlighted_pieces.clear
  end
    
  def generate_grid piece_type
    (0...@grid_width).each do |x|   
      (0...(@grid_height)).each do |y|
        piece = Piece.new self, @piece_size, x, y, piece_type
        @grid[y][x] = piece         
      end
    end   
  end

  def delete_and_fall_pieces
    return if @highlighted_pieces.length == 1
    @deleting = true
   
    @points = @points + @highlighted_pieces.length**2
    emit pointsChanged(@points)
    emit highlightedPointsChanged(0)
    
    #delete pieces
    @highlighted_pieces.each do |piece|
      @grid[piece.y][piece.x] = nil
      piece.hide        
    end  
   
    #fall pieces
    (0...@grid_width).each do |x|
      (@grid_height-1).downto(1) do |y|
        if @grid[y][x].nil?
          #find next one
          (y-1).downto(0) do |i|
            unless @grid[i][x].nil?
              @falling_pieces << @grid[i][x]
              @falling = true
              @grid[i][x].falling = true
            end 
          end
          break
        end
      end
    end   
    
    for a in (0...@grid_width)
      #find first empty column
      next unless column_empty? a
      for b in (a+1)...@grid_width        
        unless column_empty? b          
          @falling_columns << Column.new(b,0,0,true)
          @falling_sideways = true
        end        
      end
      break
    end    
    
    unless @falling_pieces.empty? and @falling_columns.empty?
      @physics_timer.start
      @falling = true
    else
      if done?
         cleared = @grid.flatten.reject{|spot| spot.nil?}.length == 0
         emit done(@points,cleared)
      end
    end
    
    @highlighted_pieces.clear
    @deleting = false
  end
  
  def column_empty? col
    for i in (0...@grid_height)
      return false if not @grid[i][col].nil?
    end
    true
  end
end
