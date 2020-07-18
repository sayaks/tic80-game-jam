-- title:  game title
-- author: LAZK
-- desc:   short description
-- script: lua

-- constants

local DRAW_FLAG = 0
local SOLID_FLAG = 1
local OPAQUE_FLAG = 2
local FLOOR_BLOCK = 3
local HALF_BLOCK = 4
local FULL_BLOCK = 5

local PALETTE_ADDR=0x03FC0

-- sample_map

local sample_map={
	{03,03,03,03,03,03,03,03},
	{03,32,32,32,01,01,01,03,32,32,32,32,32,32},
	{03,32,32,32,01,01,01,01,32,32,32,32,32,32},
	{03,32,32,32,01,03,01,05,32,32,32,32,32,32},
	{03,01,01,32,01,03,01,05,32,32,32,32,32,32},
	{03,01,32,51,32,01,01,05,32,32,32,32,32,32},
	{03,01,01,32,01,01,01,05,32,32,32,32,32,32},
	{03,01,01,01,05,01,01,05,32,32,32,32,32,32},
	{03,01,01,01,01,05,01,05},
	{03,01,01,01,01,03,01,03},
	{03,03,03,03,01,03,03,03},
	{03,01,01,03,01,03,01,03},
	{03,01,01,03,01,01,01,03},
	{03,01,01,01,01,01,01,03},
	{03,03,03,03,03,03,03,03},
}

-- palette swapping

local default_palette={}
for i=0,15 do
	local addr=PALETTE_ADDR
	local palette={
		r=peek(addr+i*3),
		g=peek(addr+1+i*3),
		b=peek(addr+2+i*3),
	}
	default_palette[i]=palette
end

local palettes={
	{r=0xFF,g=0xFF,b=0xFF}
}

function swap_palette(p)
	for k,v in pairs(p) do
		trace(PALETTE_ADDR+k*3)
		poke(PALETTE_ADDR+k*3,v.r)
		poke(PALETTE_ADDR+k*3+1,v.g)
		poke(PALETTE_ADDR+k*3+2,v.b)
	end
end

-- custom drawing

function init_node(e)
	return {l=nil,r=nil,e=e}
end

function insert(t,e)
	if e.z<t.e.z then
		if not t.l then
			t.l=init_node(e)
		else
			insert(t.l,e)
		end
	else
		if not t.r then
			t.r=init_node(e)
		else
			insert(t.r,e)
		end
	end
end

function tree_list(t)
	function inner(t,a)
		if not t then
			return a
		end
		inner(t.l,a)
		table.insert(a,t.e)
		inner(t.r,a)
		return a
	end
	return inner(t,{})
end

local drawing_tree=nil

function start_draw()
 drawing_tree=init_node({id=nil,z=136/2})
end

function final_draw()
	for k,e in pairs(tree_list(drawing_tree)) do
		if e.id then
			trace(e.y)
			spr(e.id,e.x,e.y,e.colorkey,e.scale,e.flip,e.rotate,e.w,e.h)
		end
	end
end

function pre_spr(id,x,y,colorkey,scale,flip,rotate,w,h,z)
	local e={
		id=id,x=x,y=y,
		colorkey=colorkey or -1,
		scale=scale or 1,
		flip=flip or 0,
		rotate=rotate or 0,
		w=w or 1,
		h=h or 1,
		z=y+(z or 0)
	}
	insert(drawing_tree,e)
end

-- iso helpers

function calc_iso(x,y)
	local xx=8*x
	local xy=5*x
	local yx=-8*y
	local yy=5*y 
	return xx+yx,xy+yy
end

function map_iso(x,y,w,h,sx,sy)
	for ix=x,x+w do
		for iy=y,y+h do
			if fget(iso_mget(ix,iy),DRAW_FLAG) then
				if is_visible(ix,iy) then
					local dx,dy=calc_iso(ix,iy)
					if fget(iso_mget(ix,iy),FLOOR_BLOCK) then
						spr_iso(iso_mget(ix,iy),dx+sx,dy+sy,0,1,0,0,2,2)
					elseif fget(iso_mget(ix,iy),HALF_BLOCK) then
						spr_iso(iso_mget(ix,iy),dx+sx,dy+sy,0,1,0,0,2,2)
					elseif fget(iso_mget(ix,iy),FULL_BLOCK) then
						spr_iso(iso_mget(ix,iy),dx+sx,dy+sy,0,1,0,0,2,3)
					end
					if is_visible(ix,iy) == "was visible" then
						if fget(iso_mget(ix,iy),FLOOR_BLOCK) then
							spr_iso(263,dx+sx,dy+sy,0,1,0,0,2,2)
						elseif fget(iso_mget(ix,iy),HALF_BLOCK) then
							spr_iso(261,dx+sx,dy+sy,0,1,0,0,2,2,1)
						elseif fget(iso_mget(ix,iy),FULL_BLOCK) then
							spr_iso(259,dx+sx,dy+sy,0,1,0,0,2,3,1) 
						end
					end
				end
			end
		end
	end
end

function iso_mget(x,y)
	if not sample_map[x] or 
	   not sample_map[x][y] then
		return 0
	else
		return sample_map[x][y]
	end
end

-- camera

local camera={
	x=0,y=0,w=220,h=136
}

function update_camera(c,p)
	local px,py=calc_iso(p.x,p.y)	
	
	c.x=px-c.w/2
	c.y=py-c.h/2
end

function spr_iso(index,x,y,colorkey,scale,flip,rotate,w,h,z)	
	if h>2 then
		y=y-(h-2)*8
		local nz = z or 0
		z=nz+(h-2)*8
	end
	pre_spr(index,x-camera.x,y-camera.y,colorkey,scale,flip,rotate,w,h,z)
end

--- game logic
-- player

local player={
	x=2,y=2,
	sprite=257,
	facing=0
}

-- turn handling
local turn_id=1

local turn_order={
	"player",
	"enemy"
}

function turn()
	return turn_order[turn_id]
end

function next_turn()
	turn_id=(turn_id+1)%#turn_order + 1
end

function player_turn()
	if turn()~="player" then
		return
	end
	local did_move=false
	if move_player(player) then
		did_move=true
	end
	
	if did_move then
		next_turn()
	end
end

function enemy_turn()
	if turn()~="enemy" then
		return
	end
	next_turn()
end

-- movement

function is_solid(x,y)
	return fget(iso_mget(x,y),SOLID_FLAG)
end

function move_player(p)
	local did_move=false

	if btnp(0) and not is_solid(p.x,p.y-1) then
		p.y=p.y-1
		p.facing=0
		did_move=true
	elseif btnp(1) and not is_solid(p.x,p.y+1) then
		p.y=p.y+1
		p.facing=1
		did_move=true
	end
	if btnp(2) and not is_solid(p.x-1,p.y) then
		p.x=p.x-1	
		p.facing=1
		did_move=true
	elseif btnp(3) and not is_solid(p.x+1,p.y) then
		p.x=p.x+1
		p.facing=0
		did_move=true
	end

	return did_move
end

-- visibility

local visible={}
local was_visible={}

function set_visible(x,y)
	if not visible[x] then visible[x]={} end	
	visible[x][y]=true
end

function is_visible(x,y)
	if visible[x] and visible[x][y] then
		return "visible"
	elseif was_visible[x] and was_visible[x][y] then 
		return "was visible"
	end
	return nil
end

function clear_visible()
	for x,xs in pairs(visible) do
		if not was_visible[x] then was_visible[x]={} end
		for y,ys in pairs(xs) do
			was_visible[x][y]=ys			
		end
	end
	
	visible={}
end

function dumb_visibility()
	for x=player.x-2,player.x+2 do
		for y=player.y-2,player.y+2 do
			set_visible(x,y)
		end
	end
end

function plot_line_low(x0,y0,x1,y1)
	local arr={}
	local dx=x1-x0
	local dy=y1-y0
	local yi=1
	if dy<0 then
		yi=-1
		dy=-dy
	end
	local D=2*dy-dx
	local y=y0
	for x=x0,x1 do
		table.insert(arr,{x,y})
		if D>0 then
			y=y+yi
			D=D-2*dx
		end
		D=D+2*dy
	end
	return arr
end

function plot_line_high(x0,y0,x1,y1)
	local arr={}
	local dx=x1-x0
	local dy=y1-y0
	local xi=1
	if dx<0 then
		xi=-1
		dx=-dx
	end
	local D=2*dx-dy
	local x=x0
	for y=y0,y1 do
		table.insert(arr,{x,y})
		if D>0 then
			x=x+xi
			D=D-2*dy
		end
		D=D+2*dx
	end
	return arr
end

function plot_line(x0,y0,x1,y1)
	if math.abs(y1-y0)<math.abs(x1-x0) then
		if x0>x1 then
			return plot_line_low(x1,y1,x0,y0)
		else
			return plot_line_low(x0,y0,x1,y1)
		end
	else
		if y0>y1 then
			return plot_line_high(x1,y1,x0,y0)
		else
			return plot_line_high(x0,y0,x1,y1)
			end
	end
end

function can_see(x0,y0,x1,y1)
	local arr=plot_line(x0,y0,x1,y1)	
	for k,v in pairs(arr) do
		if fget(iso_mget(v[1],v[2]),OPAQUE_FLAG) and not (x1==v[1] and y1==v[2]) then
			return false
		end
	end
	return true
end

function	shadow_casting(p,range)
	for x=p.x-range,p.x+range do
		for y=p.y-range,p.y+range do
			if can_see(p.x,p.y,x,y) then
				set_visible(x,y)
			end
		end
	end
end

-- enemy code

local enemies={}

function draw_player(p)
	local ix,iy=calc_iso(p.x,p.y)
	spr_iso(p.sprite,
		ix,iy,
		0,1,p.facing,0,2,3,1)
end

function create_enemy(x,y)
	local enemy = {
		x=x,y=y,sprite=305
	}

	function enemy:draw()
		local ix,iy=calc_iso(self.x,self.y)
		spr_iso(self.sprite,
			ix,iy,0,1,0,0,2,3,1)
	end

	table.insert(enemies,enemy)
	return enemy
end

function draw_enemies()

end

-- main
local playing_music=false
function TIC()
	cls()
	if not playing_music then
		music(0,0,0,true,true)
		playing_music=true
	end
		clear_visible()
	start_draw()
	enemy_turn()
	player_turn()
	shadow_casting(player,6)
	update_camera(camera,player)
	local dx,dy=player.x,player.y
	if dx-16<0 then dx=0 else dx=dx-16 end
	if dy-16<0 then dy=0 else dy=dy-16 end
	map_iso(dx,dy,32,32,0,0)
	draw_player(player)
	final_draw()
	
end

-- <TILES>
-- 001:000000000000000000000000000000000000000000000000000000000000000d
-- 002:00000000000000000000000000000000000000000000000000000000d0000000
-- 003:0000000f00000ffe000ffeef0ffeffeefeefeeeedddeeeeededddeeeddededde
-- 004:f0000000fff00000efeff000eeeeeff0eeeefeffeeeeeddfeeeddeefeddedeef
-- 005:0000000f00000fff000fffee0fffefeefefeeeeedddeeeeeddeddeeededdedde
-- 006:f0000000eff00000fefff000eeefeff0eeeeeeffeeeeeddfeeeddeffeddeefef
-- 007:0000000000000000000000000000660000066666000666660006566600065655
-- 008:0000000000000000000000000000000000000000660000006666000066660000
-- 017:00000dde000ddeef0ddeeffefeeddeee0ffeedde000ffeed00000ffe0000000f
-- 018:edd00000feedd000effeedd0eeeffeededdeeff0deeff000eff00000f0000000
-- 019:ddeedeefdeeeeeefddeeeeefdeeeeeefdeeeeeffdeeeeeefddeeeeffddeeeeff
-- 020:ddedeeefddeeeeefdeeeeeffddeeeeffdeeeeeefddeeeeefddeeefefdeeeeeff
-- 021:ddeeeeefddeeeeefdeeeeeffdeeefeff0fffefef000ffeff00000fff0000000f
-- 022:ddedeeefddeeefefdedeeeffddeefeffdeefeff0dfeff000dff00000d0000000
-- 023:0006555500065655000656550006565500065644000654560006546600066644
-- 024:6566000065660000556600006566000065660000456600004666000065660000
-- 032:0000000000000000000000000000000000000000000000000000000000000006
-- 033:0000000000000000000000000000000000000000000000000000000060000000
-- 035:ddeeeeffdeeeeeefddeeefefdeefeeff0ffeffef000ffeff00000fff0000000f
-- 036:deeeeeefddeeeeffdeeeefffdeeeeeffdeefeff0defff000dff00000d0000000
-- 037:0000000600000665000665650666666665555555666666666556656566655665
-- 038:6000000056600000565660006666666055555556666666665656655656655666
-- 039:0006665500065655000666650006566500006656000000660000000000000000
-- 040:6666000066660000656600006666000065660000656600006666000000660000
-- 048:0000066500066556066556656556655606655665000665550000055600000005
-- 049:5660000065566000566555506555566555566550566550006550000050000000
-- 051:0000000f00000ffe000ffeff0ffeefeefeefeeeedddeeeeeddeddeeededeedde
-- 052:f0000000fff00000efeff000eefefff0eedeefefeeededdfdeeddeefeddedeff
-- 053:6556655665555666666555566556655606655666000665560000066600000006
-- 054:6556655666655556655556666556655666655660655660006660000060000000
-- 067:dffefeff0ddfffef0feddfff00ffeddd00dffeed00de8ffd00de99ef0feddaef
-- 068:ddefeff0ddeffdd0dffdded0fddeef00fedfff00fff9ef00de8aed00de9dded0
-- 083:dffeeddfdddffedddedddffdddededdd0ffeeeef000ffeff00000fff0000000f
-- 084:dddeeffffefffddffffddefffddeefefdeefeff0dedff000dff00000d0000000
-- 225:0000000000000000000000000000000000000000000000000000000000000003
-- 226:0000000000000000000000000000000000000000000000000000000030000000
-- 227:0000000000000000000000000000000000000000000000000000000000000003
-- 228:0000000000000000000000000000000000000000000000000000000030000000
-- 241:0000033200023324033433223324233303223332000333420000032300000003
-- 242:4330000042333000233342303333243333333330344330003240000030000000
-- 243:0000033200023324034433323324233303323232000334420000032300000003
-- 244:2330000042332000233242303333442232332330342330003240000030000000
-- </TILES>

-- <SPRITES>
-- 001:000000000000000000000001000000c1000001c1000001120000011200000132
-- 002:0000000000000000110c0000111c000012200000224000004230000032000000
-- 003:0000000f000000f0000f0f0f00f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 004:00000000f0f000000f0f0000f0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 005:0000000f000000f0000f0f0f00f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 006:00000000f0f000000f0f0000f0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 008:00000000000000000000000000000000000000000000000000000000f0000000
-- 017:0000013300005515000056160000621500002056000020220000236600003365
-- 018:5150000051500000516000006500000023000000663000005630000065000000
-- 019:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 020:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- 021:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0f0000f0f000000f0f00000000
-- 022:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f00f0f0f0000f000000f0000000
-- 023:00000f0f0000f0f00f0f0f0ff0f0f0f00f0f0f0f0000f0f000000f0f00000000
-- 024:0f000000f0f0f0000f0f0f00f0f0f0f00f0f0f00f0f0f0000f000000f0000000
-- 033:0000065000000560000006500000030000000330000000000000000000000000
-- 034:5500000055000000300000003300000000000000000000000000000000000000
-- 035:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0f0000f0f000000f0f00000000
-- 036:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f00f0f0f0000f000000f0000000
-- 049:0000000200000222000222220222222222222222222222222222222222222222
-- 050:2000000022200000222220002222222022222222222222222222222222222222
-- 065:2222222222fff2ff22f2f22f22f2f22f22f2f22f22f2f22f22fff22f22222222
-- 066:22222222f2fff22222f2f22222ff222222f2f22222f2f22222f2f22222222222
-- 081:2222222222222222222222222222222202222222000222220000022200000002
-- 082:2222222222222222222222222222222222222220222220002220000020000000
-- 209:00000000000000000000000000000000000000000000000c0000c00c0000300c
-- 210:00000000000000000000000000000000ccc00000cc30c0002cc02000cc00c000
-- 211:000000000000000000000001000000c1000001c1000001120000011200000132
-- 212:0000000000000000110c0000111c000012200000224000004230000032000000
-- 225:0000c00c0000c06500000c060000000c0000000c0000006500000066000000c0
-- 226:5560c000660c000066000000000000005000000060000000c00000000c000000
-- 227:0000013300005515000056160000621500002056000020220000236600003365
-- 228:5150000051500000516000006500000023000000663000005630000065000000
-- 241:00000c0000000c00000003000000005000000c60000000000000000000000000
-- 242:0c00000002000000500000006c00000000000000000000000000000000000000
-- 243:0000065000000560000006500000030000000330000000000000000000000000
-- 244:5500000055000000300000003300000000000000000000000000000000000000
-- </SPRITES>

-- <MAP>
-- 000:304030403040304030403040304030403040304030403040304030400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:314131413141314131413141314131413141314131413141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:324232423242324232423242324232423242324232423242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:304010201020102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:314111211121112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:324212221222122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:304010201020102030403040102010203040304030403040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:314111211121112131413141112111213141314131413141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:324212221222122232423242122212223242324232423242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 024:304010201020304010201020304010203040102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 025:314111211121314111211121314111213141112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 026:324212221222324212221222324212223242122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 027:304010203040102010201020102010201020102010203040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 028:314111213141112111211121112111211121112111213141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 029:324212223242122212221222122212221222122212223242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 030:304030403040304030403040304030403040304030403040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 031:314131413141314131413141314131413141314131413141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 032:324232423242324232423242324232423242324232423242000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- 004:001123578acdeffffffedca875321100
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- 001:01073105410361027101810091009100a100b100c100d100d100e100e100e100e100e100f100f100f100f100f100f100f100f100f100f100f100f100a00000000000
-- 002:035023304330532073109300a300b300c300c300d300d300e300e300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300300000000000
-- 003:030013503300433053006310730083509300a320b300c330c300d310d300e300e300e300f300f300f300f300f300f300f300f300f300f300f300f300600000000000
-- 004:030043007300b300d300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300f300700000000000
-- 005:f00be00cd00ec00fc000b000a00090008000700060005000400030001000000000000000000000000000000000000000000000000000000000000000100000000000
-- 006:0200220062009200b200c200e200e200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200400000000000
-- 007:f400e401c4035404040304010400040f040d040c040d040f04000400040004000400040004000400040004000400040004000400040004000400040040000000000c
-- </SFX>

-- <PATTERNS>
-- 000:90001200000000000000000090003c00000000000000000090002400000000000000000090003c00000000000090004c90004c00000090004c00000090001200000090004c00000090002400000000000000000090003c00000090004c00000090001200000000000000000090003c00000000000000000090002400000000000000000090003c00000000000090004c90004c00000090004c00000090001200000090004c00000090002400000090001200000090002400000090004c000000
-- 001:900050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000900052000000000000000000900050000000000000000000000000000000000000000000000000000000000000000000600050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600052000000000000000000600050000000000000000000000000000000000000000000000000000000000000000000
-- 002:900050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000900052000000000000000000900050000000000000000000000000000000000000000000000000000000000000000000400050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400052000000000000000000400050000000000000000000000000000000000000000000000000000000000000000000
-- 003:900064c00064400066900064c00064400066900064c00064000000000000c00064000000900064000000400066000000900064c00064400066900064400066000000400066000000900068000000900068000000900064c00064900064c00064800064900064c00064800064900064c00064800064900064000000000000900064000000800064000000c00064000000800064900064c00064800064000000000000800064000000900064000000c00064000000800064c00064800064c00064
-- 004:000000000000000000000000900078000000000000000000000000000000000000000000c0007800000040007a000000000000000000000000000000000000000000000000000000900078000000000000000000000000000000000000000000000000000000000000000000600078000000000000000000000000000000000000000000900078000000000000000000600078000000000000000000000000000000600078000000000000000000000000000000600078000000000000000000
-- </PATTERNS>

-- <TRACKS>
-- 000:1805001c04830000000000000000000000000000000000000000000000000000000000000000000000000000000000006f0000
-- </TRACKS>

-- <FLAGS>
-- 000:009080726231000000000000000000000080806262000000000000000000000090000062623100000000000000000000000000720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b000b000000000000000000000000000000000000000000000000000000000
-- </FLAGS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53952c40ffcd7550404038281818203c1c792c20482c0830045d1855ffffe294b0c2566c86343c57
-- </PALETTE>

