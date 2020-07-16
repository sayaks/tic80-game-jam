-- title:  game title
-- author: LAZK
-- desc:   short description
-- script: lua

function is_dyn(x,y)
		return fget(mget(x,y),0)
end

local dirs={
	{0,-1},
	{1,0},
	{0,1},
	{-1,0}
}

function remap(tile,x,y)
	if not fget(tile,0) then
		return
	end
	--tile=tile + 3*((y//3)%4) -- season test
	local c=0
	for k,d in pairs(dirs) do
		if is_dyn(x+d[1],y+d[2]) then c=c+1 end
	end 
	if c==0 or c==4 then
		return tile
	elseif c==1 then
		local rot=2
		for k,d in pairs(dirs) do
			if is_dyn(x+d[1],y+d[2]) then
				return tile-1,0,rot%4
			end
			rot=rot+1
		end
	elseif c==3 then
		local rot=0
		for k,d in pairs(dirs) do
			if not is_dyn(x+d[1],y+d[2]) then
				return tile-1,0,rot%4
			end
			rot=rot+1
		end
	elseif c==2 then
		local s=0
		local rot=-1
		for k,d in pairs(dirs) do
			if s==0 and not is_dyn(x+d[1],y+d[2]) then
				s=1
			end
			if s==1 and is_dyn(x+d[1],y+d[2]) then
				return tile-2,0,rot%4
			end
			rot=rot+1
		end
		return tile-2,0,rot%4
	end
	
	return tile
end

local player={
	x=0,y=0,
	dx=0,dy=0,
	w=16,h=16,
	sprite=257,
	facing="r",
	state="idle"
}

local camera={
	x=0,y=0,
	w=240,h=136
}

local flip_map={r=0,l=1}
local grav=90
local speed=60
local jump=90

function draw(c)
	spr(
		c.sprite,
		c.x-(camera.x-camera.w/2),
		c.y-(camera.y-camera.h/2),
		0,
		1,flip_map[c.facing],0,
		c.w//2,c.h//2
	)
end

function is_solid(x,y)
	return mget(x,y) > 0 and mget(x,y) < 100
end

function update_player(p)
	p.dy=p.dy+grav/60

	-- if hits floor
	if is_solid(p.x//8,(p.y+p.dy/60+p.h)//8) or
	   is_solid((p.x+p.h)//8,(p.y+p.dy/60+p.h)//8) then
		p.dy = 0
	end
	
	-- if hits roof
	if is_solid(p.x//8,(p.y+p.dy/60)//8) or
	   is_solid((p.x+p.h)//8,(p.y+p.dy/60)//8) then
		p.dy = 0
	end
	
	p.y=p.y+p.dy/60

	if btn(3) then
		p.dx=speed
	elseif btn(2) then
		p.dx=-speed
	else
		p.dx=0
	end
	
	if btnp(0) then
		p.dy=-jump
	end

	if is_solid((p.x+p.dx/60)//8,(p.y+p.dy/60)//8) or
	   is_solid((p.x+p.dx/60+p.w)//8,(p.y+p.dy/60)//8) or
	   is_solid((p.x+p.dx/60)//8,(p.y+p.dy/60+p.h)//8) or
	   is_solid((p.x+p.dx/60+p.w)//8,(p.y+p.dy/60+p.h)//8) then
		p.dx=0
	end	
	p.x=p.x+p.dx/60
end

function update_camera(c,p)
	if p.x < c.w/2 then
		c.x=c.w/2
	else
		c.x=p.x
	end
	if p.y < c.h/2 then
		c.y=c.h/2
	else
		c.y=p.y
	end
end

function TIC()
	cls()
	map((camera.x-camera.w/2)//8,
	    (camera.y-camera.h/2)//8,
	     camera.w//8,camera.h//8,
					-(camera.x%8),-((camera.y-4)%8),
					0,1,remap)
	update_player(player)
	update_camera(camera,player)
	draw(player)
end
-- <TILES>
-- 001:0000060006000006060006060006060000066606066666660006666600666666
-- 002:0060000600600006600006006606060066666606666666666666666666666666
-- 003:6666666666666666666666666666666666666666666666666666666666666666
-- 004:0002242204242224042224242224242224244424244244452224444442445455
-- 005:4242242422422224422224225424252244444424554554454544454455545555
-- 006:4444444445444554455545444445555444545444454544544444544444444444
-- 007:0002222202222222022222222222222222222222222222232222222222223233
-- 008:2222222222222222222222222222222222222222332332232322232233323333
-- 009:2222222223222322222322222232323222332222232332322232322222222222
-- 010:000ddddd0ddbbbbb0ddbccccddbbcbbbdbbcccccdbbcbcccdbccccccdbcbcccc
-- 011:dddddddddbddbddddbbbbbdbbbcbccbccccbcccbbccbcbbccccccccccccccccc
-- 012:cccccccccbbbcbcccccbbbbccbbbbcbccbbccbbccbbbbcbccbcbbbcccccccccc
-- 013:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
-- </TILES>

-- <SPRITES>
-- 001:0020020202020202020002020200020202000222020002020200020222000202
-- 002:0020022002020202020202020202020202220220020202020202020202020202
-- 017:0200020202000202020002020200020202000202020202020020020200000000
-- 018:0202020202020202020202020202020202020202020202020202020200000000
-- </SPRITES>

-- <MAP>
-- 007:000000000000000000000000000000303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:000000000000000000000000000000303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:000030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:000030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:003030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:003030303030000000000000000000003030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:000000000000000000000000000000003030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <FLAGS>
-- 000:00101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </FLAGS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

