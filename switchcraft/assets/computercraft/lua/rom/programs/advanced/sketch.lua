if OneOS then
	--running under OneOS
	OneOS.ToolBarColour = colours.grey
	OneOS.ToolBarTextColour = colours.white
end

colours.transparent = -1
colors.transparent = -1

--APIS--

--This is my drawing API, is is pretty much identical to what drives OneOS, PearOS, etc.
local _w, _h = term.getSize()

local round = function(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

Clipboard = {
	Content = nil,
	Type = nil,
	IsCut = false,

	Empty = function()
		Clipboard.Content = nil
		Clipboard.Type = nil
		Clipboard.IsCut = false
	end,

	isEmpty = function()
		return Clipboard.Content == nil
	end,

	Copy = function(content, _type)
		Clipboard.Content = content
		Clipboard.Type = _type or 'generic'
		Clipboard.IsCut = false
	end,

	Cut = function(content, _type)
		Clipboard.Content = content
		Clipboard.Type = _type or 'generic'
		Clipboard.IsCut = true
	end,

	Paste = function()
		local c, t = Clipboard.Content, Clipboard.Type
		if Clipboard.IsCut then
			Clipboard.Empty()
		end
		return c, t
	end
}

if OneOS and OneOS.Clipboard then
	Clipboard = OneOS.Clipboard
end

Drawing = {
	
	Screen = {
		Width = _w,
		Height = _h
	},

	DrawCharacters = function (x, y, characters, textColour,bgColour)
		Drawing.WriteStringToBuffer(x, y, characters, textColour, bgColour)
	end,
	
	DrawBlankArea = function (x, y, w, h, colour)
		Drawing.DrawArea (x, y, w, h, " ", 1, colour)
	end,

	DrawArea = function (x, y, w, h, character, textColour, bgColour)
		--width must be greater than 1, other wise we get a stack overflow
		if w < 0 then
			w = w * -1
		elseif w == 0 then
			w = 1
		end

		for ix = 1, w do
			local currX = x + ix - 1
			for iy = 1, h do
				local currY = y + iy - 1
				Drawing.WriteToBuffer(currX, currY, character, textColour, bgColour)
			end
		end
	end,

	DrawImage = function(_x,_y,tImage, w, h)
		if tImage then
			for y = 1, h do
				if not tImage[y] then
					break
				end
				for x = 1, w do
					if not tImage[y][x] then
						break
					end
					local bgColour = tImage[y][x]
		            local textColour = tImage.textcol[y][x] or colours.white
		            local char = tImage.text[y][x]
		            Drawing.WriteToBuffer(x+_x-1, y+_y-1, char, textColour, bgColour)
				end
			end
		elseif w and h then
			Drawing.DrawBlankArea(x, y, w, h, colours.green)
		end
	end,
	--using .nft
	LoadImage = function(path)
		local image = {
			text = {},
			textcol = {}
		}
		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		if _fs.exists(path) then
			local _open = io.open
			if OneOS then
				_open = OneOS.IO.open
			end
	        local file = _open(path, "r")
	        local sLine = file:read()
	        local num = 1
	        while sLine do  
	                table.insert(image, num, {})
	                table.insert(image.text, num, {})
	                table.insert(image.textcol, num, {})
	                                            
	                --As we're no longer 1-1, we keep track of what index to write to
	                local writeIndex = 1
	                --Tells us if we've hit a 30 or 31 (BG and FG respectively)- next char specifies the curr colour
	                local bgNext, fgNext = false, false
	                --The current background and foreground colours
	                local currBG, currFG = nil,nil
	                for i=1,#sLine do
	                        local nextChar = string.sub(sLine, i, i)
	                        if nextChar:byte() == 30 then
                                bgNext = true
	                        elseif nextChar:byte() == 31 then
                                fgNext = true
	                        elseif bgNext then
                                currBG = Drawing.GetColour(nextChar)
                                bgNext = false
	                        elseif fgNext then
                                currFG = Drawing.GetColour(nextChar)
                                fgNext = false
	                        else
                                if nextChar ~= " " and currFG == nil then
                                       currFG = colours.white
                                end
                                image[num][writeIndex] = currBG
                                image.textcol[num][writeIndex] = currFG
                                image.text[num][writeIndex] = nextChar
                                writeIndex = writeIndex + 1
	                        end
	                end
	                num = num+1
	                sLine = file:read()
	        end
	        file:close()
		end
	 	return image
	end,

	DrawCharactersCenter = function(x, y, w, h, characters, textColour,bgColour)
		w = w or Drawing.Screen.Width
		h = h or Drawing.Screen.Height
		x = x or 0
		y = y or 0
		x = math.ceil((w - #characters) / 2) + x
		y = math.floor(h / 2) + y

		Drawing.DrawCharacters(x, y, characters, textColour, bgColour)
	end,

	GetColour = function(hex)
		if hex == ' ' then
			return colours.transparent
		end
	    local value = tonumber(hex, 16)
	    if not value then return nil end
	    value = math.pow(2,value)
	    return value
	end,

	Clear = function (_colour)
		_colour = _colour or colours.black
		Drawing.ClearBuffer()
		Drawing.DrawBlankArea(1, 1, Drawing.Screen.Width, Drawing.Screen.Height, _colour)
	end,

	Buffer = {},
	BackBuffer = {},

	DrawBuffer = function()
		for y,row in pairs(Drawing.Buffer) do
			for x,pixel in pairs(row) do
				local shouldDraw = true
				local hasBackBuffer = true
				if Drawing.BackBuffer[y] == nil or Drawing.BackBuffer[y][x] == nil or #Drawing.BackBuffer[y][x] ~= 3 then
					hasBackBuffer = false
				end
				if hasBackBuffer and Drawing.BackBuffer[y][x][1] == Drawing.Buffer[y][x][1] and Drawing.BackBuffer[y][x][2] == Drawing.Buffer[y][x][2] and Drawing.BackBuffer[y][x][3] == Drawing.Buffer[y][x][3] then
					shouldDraw = false
				end
				if shouldDraw then
					term.setBackgroundColour(pixel[3])
					term.setTextColour(pixel[2])
					term.setCursorPos(x, y)
					term.write(pixel[1])
				end
			end
		end
		Drawing.BackBuffer = Drawing.Buffer
		Drawing.Buffer = {}
		term.setCursorPos(1,1)
	end,

	ClearBuffer = function()
		Drawing.Buffer = {}
	end,

	WriteStringToBuffer = function (x, y, characters, textColour,bgColour)
		for i = 1, #characters do
   			local character = characters:sub(i,i)
   			Drawing.WriteToBuffer(x + i - 1, y, character, textColour, bgColour)
		end
	end,

	WriteToBuffer = function(x, y, character, textColour,bgColour)
		x = round(x)
		y = round(y)
		if bgColour == colours.transparent then
			Drawing.Buffer[y] = Drawing.Buffer[y] or {}
			Drawing.Buffer[y][x] = Drawing.Buffer[y][x] or {"", colours.white, colours.black}
			Drawing.Buffer[y][x][1] = character
			Drawing.Buffer[y][x][2] = textColour
		else
			Drawing.Buffer[y] = Drawing.Buffer[y] or {}
			Drawing.Buffer[y][x] = {character, textColour, bgColour}
		end
	end,
}

--Colour Deffitions--
UIColours = {
	Toolbar = colours.grey,
	ToolbarText = colours.lightGrey,
	ToolbarSelected = colours.lightBlue,
	ControlText = colours.white,
	ToolbarItemTitle = colours.black,
	Background = colours.lightGrey,
	MenuBackground = colours.white,
	MenuText = colours.black,
	MenuSeparatorText = colours.grey,
	MenuDisabledText = colours.lightGrey,
	Shadow = colours.grey,
	TransparentBackgroundOne = colours.white,
	TransparentBackgroundTwo = colours.lightGrey,
	MenuBarActive = colours.white
}

--Lists--
Current = {
	Artboard = nil,
	Layer = nil,
	Tool = nil,
	ToolSize = 1,
	Toolbar = nil,
	Colour = colours.lightBlue,
	Menu = nil,
	MenuBar = nil,
	Window = nil,
	Input = nil,
	CursorPos = {1,1},
	CursorColour = colours.black,
	InterfaceVisible = true,
	Selection = {},
	SelectionDrawTimer = nil,
	HandDragStart = {},
	Modified = false,
}

local isQuitting = false

function PrintCentered(text, y)
    local w, h = term.getSize()
    x = math.ceil(math.ceil((w / 2) - (#text / 2)), 0)+1
    term.setCursorPos(x, y)
    print(text)
end

function DoVanillaClose()
	term.setBackgroundColour(colours.black)
	term.setTextColour(colours.white)
	term.clear()
	term.setCursorPos(1, 1)
	PrintCentered("Thanks for using Sketch!", (Drawing.Screen.Height/2)-1)
	term.setTextColour(colours.lightGrey)
	PrintCentered("Photoshop Inspired Image Editor for ComputerCraft", (Drawing.Screen.Height/2))
	term.setTextColour(colours.white)
	PrintCentered("(c) oeed 2013 - 2014", (Drawing.Screen.Height/2)+3)
	term.setCursorPos(1, Drawing.Screen.Height)
	error('', 0)
end

function Close()
	if isQuitting or not Current.Artboard or not Current.Modified then
		if not OneOS then
			DoVanillaClose()
		end
		return true
	else
		local _w = ButtonDialougeWindow:Initialise('Quit Sketch?', 'You have unsaved changes, do you want to quit anyway?', 'Quit', 'Cancel', function(window, success)
			if success then
				if OneOS then
					OneOS.Close(true)
				else
					DoVanillaClose()
				end
			end
			window:Close()
			Draw()
		end):Show()
		--it's hacky but it works
		os.queueEvent('mouse_click', 1, _w.X, _w.Y)
		return false
	end
end

if OneOS then
	OneOS.CanClose = function()
		return Close()
	end
end

Lists = {
	Artboards = {},
	Interface = {
		Toolbars = {}
	}	
}

Events = {
	
}

--Setters--

function SetColour(colour)
	Current.Colour = colour
	Draw()
end

function SetTool(tool)
	if tool and tool.Select and tool:Select() then
		Current.Input = nil
		Current.Tool = tool
		return true
	end
	return false
end

function GetAbsolutePosition(object)
	local obj = object
	local i = 0
	local x = 1
	local y = 1
	while true do
		x = x + obj.X - 1
		y = y + obj.Y - 1

		if not obj.Parent then
			return {X = x, Y = y}
		end

		obj = obj.Parent

		if i > 32 then
			return {X = 1, Y = 1}
		end

		i = i + 1
	end

end

--Object Defintions--

Pixel = {
	TextColour = colours.black,
	BackgroundColour = colours.white,
	Character = " ",
	Layer = nil,

	Draw = function(self, x, y)
		if self.BackgroundColour ~= colours.transparent or self.Character ~= ' ' then
			Drawing.WriteToBuffer(self.Layer.Artboard.X + x - 1, self.Layer.Artboard.Y + y - 1, self.Character, self.TextColour, self.BackgroundColour)
		end
	end,

	Initialise = function(self, textColour, backgroundColour, character, layer)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.TextColour = textColour or self.TextColour
		new.BackgroundColour = backgroundColour or self.BackgroundColour
		new.Character = character or self.Character
		new.Layer = layer
		return new
	end,

	Set = function(self, textColour, backgroundColour, character)
		self.TextColour = textColour or self.TextColour
		self.BackgroundColour = backgroundColour or self.BackgroundColour
		self.Character = character or self.Character
	end
}

Layer = {
	Name = "",
	Pixels = {

	},
	Artboard = nil,
	BackgroundColour = colours.white,
	Visible = true,
	Index = 1,

	Draw = function(self)
		if self.Visible then
			for x = 1, self.Artboard.Width do
				for y = 1, self.Artboard.Height do
					self.Pixels[x][y]:Draw(x, y)
				end
			end
		end
	end,

	Remove = function(self)
		for i, v in ipairs(self.Artboard.Layers) do
			if v == Current.Layer then
				Current.Artboard.Layers[i] = nil
				Current.Layer = Current.Artboard.Layers[1]
				ModuleNamed('Layers'):Update()
			end
		end
	end,

	Initialise = function(self, name, backgroundColour, artboard, index, pixels)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Name = name
		new.Pixels = {}
		new.BackgroundColour = backgroundColour
		new.Artboard = artboard
		new.Index = index or #artboard.Layers + 1
		if not pixels then
			new:MakeAllBlankPixels()
		else
			new:MakeAllBlankPixels()
			for x, col in ipairs(pixels) do
				for y, pixel in ipairs(col) do
					new:SetPixel(x, y, pixel.TextColour, pixel.BackgroundColour, pixel.Character)
				end
			end
		end
		
		return new
	end,

	SetPixel = function(self, x, y, textColour, backgroundColour, character)
		textColour = textColour or Current.Colour
		backgroundColour = backgroundColour or Current.Colour
		character = character or " "

		if x < 1 or y < 1 or x > self.Artboard.Width or y > self.Artboard.Height then
			return
		end

		if self.Pixels[x][y] then
			self.Pixels[x][y]:Set(textColour, backgroundColour, character)
			self.Pixels[x][y]:Draw(x,y)
		end
	end,

	MakePixel = function(self, x, y, backgroundColour)
		backgroundColour = backgroundColour or self.BackgroundColour			
		self.Pixels[x][y] = Pixel:Initialise(nil, backgroundColour, nil, self)
	end,

	MakeColumn = function(self, x)
		self.Pixels[x] = {}
	end,

	MakeAllBlankPixels = function(self)
		for x = 1, self.Artboard.Width do
			if not self.Pixels[x] then
				self:MakeColumn(x)
			end

			for y = 1, self.Artboard.Height do			
			
				if not self.Pixels[x][y] then
					self:MakePixel(x, y)
				end

			end
		end
	end,

	PixelsInSelection = function(self, cut)
		local pixels = {}
		if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
			local point1 = Current.Selection[1]
			local point2 = Current.Selection[2]

			local size = point2 - point1
			local cornerX = point1.x
			local cornerY = point1.y
			for x = 1, size.x + 1 do
				for y = 1, size.y + 1 do
					if not pixels[x] then
						pixels[x] = {}
					end
					if not self.Pixels[cornerX + x - 1] or not self.Pixels[cornerX + x - 1][cornerY + y - 1] then
						break
					end
					local pixel =  self.Pixels[cornerX + x - 1][cornerY + y - 1]
					pixels[x][y] = Pixel:Initialise(pixel.TextColour, pixel.BackgroundColour, pixel.Character, Current.Layer)
					if cut then
						Current.Layer:SetPixel(cornerX + x - 1, cornerY + y - 1, nil, Current.Layer.BackgroundColour, nil)
					end
				end
			end
		end
		return pixels
	end,

	EraseSelection = function(self)
		if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
			local point1 = Current.Selection[1]
			local point2 = Current.Selection[2]

			local size = point2 - point1
			local cornerX = point1.x
			local cornerY = point1.y
			for x = 1, size.x + 1 do
				for y = 1, size.y + 1 do
					Current.Layer:SetPixel(cornerX + x - 1, cornerY + y - 1, nil, Current.Layer.BackgroundColour, nil)
				end
			end
		end
	end,

	InsertPixels = function(self, pixels)
		local cornerX = Current.Selection[1].x
		local cornerY = Current.Selection[1].y
		for x, col in ipairs(pixels) do
			for y, pixel in ipairs(col) do
				Current.Layer:SetPixel(cornerX + x - 1, cornerY + y - 1, pixel.TextColour, pixel.BackgroundColour, pixel.Character)
			end
		end
	end
}

Artboard = {
	X = 0,
	Y = 0,
	Name = "",
	Path = "",
	Width = 1,
	Height = 1,
	Layers = {},
	Format = nil,
	SelectionIsBlack = true,

	Draw = function(self)
		Drawing.DrawBlankArea(self.X + 1, self.Y + 1, self.Width, self.Height, UIColours.Shadow)

		local odd
		for x = 1, self.Width do
			odd = x % 2
			if odd == 1 then
				odd = true
			else
				odd = false
			end
			for y = 1, self.Height do
				if odd then
					Drawing.WriteToBuffer(self.X + x - 1, self.Y + y - 1, ":", UIColours.TransparentBackgroundTwo, UIColours.TransparentBackgroundOne)
				else
					Drawing.WriteToBuffer(self.X + x - 1, self.Y + y - 1, ":", UIColours.TransparentBackgroundOne, UIColours.TransparentBackgroundTwo)
				end

				odd = not odd
			end
		end

		for i, layer in ipairs(self.Layers) do
			layer:Draw()
		end

		if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
			local point1 = Current.Selection[1]
			local point2 = Current.Selection[2]

			local size = point2 - point1

			local isBlack = self.SelectionIsBlack

			local function c()
				local c = colours.white
				if isBlack then
					c = colours.black
				end
				isBlack = not isBlack
				return c
			end

			function horizontal(y)
				Drawing.WriteToBuffer(self.X - 1 + point1.x, self.Y - 1 + y, '+', c(), colours.transparent)
				if size.x > 0 then
					for i = 1, size.x - 1 do
						Drawing.WriteToBuffer(self.X - 1 + point1.x + i, self.Y - 1 + y, '-', c(), colours.transparent)
					end
				else
					for i = 1, (-1 * size.x) - 1 do
						Drawing.WriteToBuffer(self.X - 1 + point1.x - i, self.Y - 1 + y, '-', c(), colours.transparent)
					end
				end

				Drawing.WriteToBuffer(self.X - 1 + point1.x + size.x, self.Y - 1 + y, '+', c(), colours.transparent)
			end

			function vertical(x)
				if size.y < 0 then
					for i = 1, (-1 * size.y) - 1 do
						Drawing.WriteToBuffer(self.X - 1 + x, self.Y - 1 + point1.y  - i, '|', c(), colours.transparent)
					end
				else
					for i = 1, size.y - 1 do
						Drawing.WriteToBuffer(self.X - 1 + x, self.Y - 1 + point1.y  + i, '|', c(), colours.transparent)
					end
				end
			end

			horizontal(point1.y)
			vertical(point1.x)
			horizontal(point1.y + size.y)
			vertical(point1.x + size.x)
		end
	end,

	Initialise = function(self, name, path, width, height, format, backgroundColour, layers)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Y = 3
		new.X = 2
		new.Name = name
		new.Path = path
		new.Width = width
		new.Height = height
		new.Format = format
		new.Layers = {}
		if not layers then
			new:MakeLayer('Background', backgroundColour)
		else
			for i, layer in ipairs(layers) do
				new:MakeLayer(layer.Name, layer.BackgroundColour, layer.Index, layer.Pixels)
				new.Layers[i].Visible = layer.Visible
			end
			Current.Layer = new.Layers[#new.Layers]
		end
		return new
	end,

	Resize = function(self, top, bottom, left, right)
		self.Height = self.Height + top + bottom
		self.Width = self.Width + left + right

		for i, layer in ipairs(self.Layers) do

			if left < 0 then
				for x = 1, -left do
					table.remove(layer.Pixels, 1)
				end
			end

			if right < 0 then
				for x = 1, -right do
					table.remove(layer.Pixels, #layer.Pixels)
				end
			end

			for x = 1, left do
				table.insert(layer.Pixels, 1, {})
				for y = 1, self.Height do
					layer:MakePixel(1, y)
				end
			end

			for x = 1, right do
				table.insert(layer.Pixels, {})
				for y = 1, self.Height do
					layer:MakePixel(#layer.Pixels, y)
				end
			end

			for y = 1, top do
				for x = 1, self.Width do
					table.insert(layer.Pixels[x], 1, {})
					layer:MakePixel(x, 1)
				end
			end

			for y = 1, bottom do
				for x = 1, self.Width do
					table.insert(layer.Pixels[x], {})
					layer:MakePixel(x, #layer.Pixels[x])
				end
			end

			if top < 0 then
				for y = 1, -top do
					for x = 1, self.Width do
						table.remove(layer.Pixels[x], 1)
					end
				end
			end

			if bottom < 0 then
				for y = 1, -bottom do
					for x = 1, self.Width do
						table.remove(layer.Pixels[x], #layer.Pixels[x])
					end
				end
			end
		end
	end,

	MakeLayer = function(self, name, backgroundColour, index, pixels)
		backgroundColour = backgroundColour or colours.white
		name = name or "Layer"
		local layer = Layer:Initialise(name, backgroundColour, self, index, pixels)
		table.insert(self.Layers, layer)
		Current.Layer = layer
		ModuleNamed('Layers'):Update()
		return layer
	end,

	New = function(self, name, path, width, height, format, backgroundColour, layers)
		local new = self:Initialise(name, path, width, height, format, backgroundColour, layers)
		table.insert(Lists.Artboards, new)
		Current.Artboard = new
		--new:Save()
		return new
	end,

	Save = function(self, path)
		Current.Artboard = self
		path = path or self.Path
		local _open = io.open
		if OneOS then
			_open = OneOS.IO.open
		end
        local file = _open(path, "w", true)
		if self.Format == '.skch' then
			file:write(textutils.serialize(SaveSKCH()))
		else
			local lines = {}
			if self.Format == '.nfp' then
				lines = SaveNFP()
			elseif self.Format == '.nft' then
				lines = SaveNFT()
			end

			for i, line in ipairs(lines) do
                file:write(line.."\n")
			end
		end
		file:close()
		Current.Modified = false
	end,

	Click = function(self, side, x, y, drag)
		if Current.Tool and Current.Layer and Current.Layer.Visible then
			Current.Tool:Use(x, y, side, drag)
			Current.Modified = true
			return true
		end
	end
}

Toolbar = {
	X = 0,
	Y = 0,
	Width = 0,
	ExpandedWidth = 14,
	ClosedWidth = 2,
	Height = 0,
	Expanded = true,
	ToolbarItems = {},

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		self:CalculateToolbarItemPositions()
		--Drawing.DrawArea(self.X - 1, self.Y, 1, self.Height, "|", UIColours.ToolbarText, UIColours.Background)

		

		--if not Current.Window then
			Drawing.DrawBlankArea(self.X, self.Y, self.Width, self.Height, UIColours.Toolbar)
		--else
		--	Drawing.DrawArea(self.X, self.Y, self.Width, self.Height, '|', colours.lightGrey, UIColours.Toolbar)
		--end
		for i, toolbarItem in ipairs(self.ToolbarItems) do
			toolbarItem:Draw()
		end
	end,

	Initialise = function(self, side, expanded)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Expanded = expanded

		if expanded then
			new.Width = new.ExpandedWidth
		else
			new.Width = new.ClosedWidth
		end

		if side == 'right' then
			new.X = Drawing.Screen.Width - new.Width + 1
		end

		if side == 'right' or side == 'left' then
			new.Height = Drawing.Screen.Width
		end

		new.Y = 1

		return new
	end,

	AddToolbarItem = function(self, item)
		table.insert(self.ToolbarItems, item)
		self:CalculateToolbarItemPositions()
	end,

	CalculateToolbarItemPositions = function(self)
		local currY = 1
		for i, toolbarItem in ipairs(self.ToolbarItems) do
			toolbarItem.Y = currY
			currY = currY + toolbarItem.Height
		end
	end,

	Update = function(self)
		for i, toolbarItem in ipairs(self.ToolbarItems) do
			if toolbarItem.Module.Update then
				toolbarItem.Module:Update(toolbarItem)
			end
		end
	end,

	New = function(self, side, expanded)
		local new = self:Initialise(side, expanded)

		--new:AddToolbarItem(ToolbarItem:Initialise("Colours", nil, true, new))
		--new:AddToolbarItem(ToolbarItem:Initialise("IDK", true, new))

		table.insert(Lists.Interface.Toolbars, new)
		return new
	end,

	Click = function(self, side, x, y)
		return false
	end
}

ToolbarItem = {
	X = 0,
	Y = 0,
	Width = 0,
	Height = 0,
	ExpandedHeight = 5,
	Expanded = true,
	Toolbar = nil,
	Title = "",
	MenuIcon = "=",
	ExpandedIcon = "+",
	ContractIcon = "-",
	ContentView = nil,
	Module = nil,
	MenuItems = nil,

	Draw = function(self)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 1, UIColours.ToolbarItemTitle)
		Drawing.DrawCharacters(self.X + 1, self.Y, self.Title, UIColours.ToolbarText, UIColours.ToolbarItemTitle)

		Drawing.DrawCharacters(self.X + self.Width - 1, self.Y, self.MenuIcon, UIColours.ToolbarText, UIColours.ToolbarItemTitle)

		local expandContractIcon = self.ContractIcon
		if not self.Expanded then
			expandContractIcon = self.ExpandedIcon
		end

		if self.Expanded and self.ContentView then
			self.ContentView:Draw()
		end

		Drawing.DrawCharacters(self.X + self.Width - 2, self.Y, expandContractIcon, UIColours.ToolbarText, UIColours.ToolbarItemTitle)
	end,

	Initialise = function(self, module, height, expanded, toolbar, menuItems)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Expanded = expanded
		new.Title = module.Title
		new.Width = toolbar.Width
		new.Height = height or 5
		new.Module = module
		new.MenuItems = menuItems or {}
		table.insert(new.MenuItems,
			{
				Title = 'Shrink',
				Click = function()
					new:ToggleExpanded()
				end
			})
		new.ExpandedHeight = height or 5
		new.Y = 1
		new.X = toolbar.X
		new.ContentView = ContentView:Initialise(1, 2, new.Width, new.Height - 1, nil, new)
		new.Toolbar = toolbar

		return new
	end,

	ToggleExpanded = function(self)
		self.Expanded = not self.Expanded
		if self.Expanded then
			self.Height = self.ExpandedHeight
		else
			self.Height = 1
		end
	end,

	Click = function(self, side, x, y)
		local pos = GetAbsolutePosition(self)
		if x == self.Width and y == 1 then
			local expandContract = "Shrink"

			if not self.Expanded then
				expandContract = "Expand"
			end
			self.MenuItems[#self.MenuItems].Title = expandContract
			Menu:New(pos.X + x, pos.Y + y, self.MenuItems, self)
			return true
		elseif x == self.Width - 1 and y == 1 then
			self:ToggleExpanded()
			return true
		elseif y ~= 1 then
			return self.ContentView:Click(side,  x - self.ContentView.X + 1,  y - self.ContentView.Y + 1)
		end

		return false
	end
}

ContentView = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	Parent = nil,
	Views = {},

	AbsolutePosition = function(self)
		return self.Parent:AbsolutePosition()
	end,

	Draw = function(self)
		for i, view in ipairs(self.Views) do
			view:Draw()
		end
	end,

	Initialise = function(self, x, y, width, height, views, parent)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = width
		new.Height = height
		new.Y = y
		new.X = x
		new.Views = views or {}
		new.Parent = parent
		return new
	end,

	Click = function(self, side, x, y)
		for k, view in pairs(self.Views) do
			if DoClick(view, side, x, y) then
				return true
			end
		end
	end
}

Button = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	BackgroundColour = colours.lightGrey,
	TextColour = colours.white,
	ActiveBackgroundColour = colours.lightGrey,
	Text = "",
	Parent = nil,
	_Click = nil,
	Toggle = nil,

	AbsolutePosition = function(self)
		return self.Parent:AbsolutePosition()
	end,

	Draw = function(self)
		local bg = self.BackgroundColour
		local tc = self.TextColour
		if type(bg) == 'function' then
			bg = bg()
		end

		if self.Toggle then
			tc = UIColours.MenuBarActive
			bg = self.ActiveBackgroundColour
		end

		local pos = GetAbsolutePosition(self)
		Drawing.DrawBlankArea(pos.X, pos.Y, self.Width, self.Height, bg)
		Drawing.DrawCharactersCenter(pos.X, pos.Y, self.Width, self.Height, self.Text, tc, bg)
	end,

	Initialise = function(self, x, y, width, height, backgroundColour, parent, click, text, textColour, toggle, activeBackgroundColour)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		height = height or 1
		new.Width = width or #text + 2
		new.Height = height
		new.Y = y
		new.X = x
		new.Text = text or ""
		new.BackgroundColour = backgroundColour or colours.lightGrey
		new.TextColour = textColour or colours.white
		new.ActiveBackgroundColour = activeBackgroundColour or colours.lightGrey
		new.Parent = parent
		new._Click = click
		new.Toggle = toggle
		return new
	end,

	Click = function(self, side, x, y)
		if self._Click then
			if self:_Click(side, x, y, not self.Toggle) ~= false and self.Toggle ~= nil then
				self.Toggle = not self.Toggle
				Draw()
			end
			return true
		else
			return false
		end
	end
}

TextBox = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	BackgroundColour = colours.lightGrey,
	TextColour = colours.black,
	Parent = nil,
	TextInput = nil,

	AbsolutePosition = function(self)
		return self.Parent:AbsolutePosition()
	end,

	Draw = function(self)		
		local pos = GetAbsolutePosition(self)
		Drawing.DrawBlankArea(pos.X, pos.Y, self.Width, self.Height, self.BackgroundColour)
		local text = self.TextInput.Value
		if #text > (self.Width - 2) then
			text = text:sub(#text-(self.Width - 3))
			if Current.Input == self.TextInput then
				Current.CursorPos = {pos.X + 1 + self.Width-2, pos.Y}
			end
		else
			if Current.Input == self.TextInput then
				Current.CursorPos = {pos.X + 1 + self.TextInput.CursorPos, pos.Y}
			end
		end
		Drawing.DrawCharacters(pos.X + 1, pos.Y, text, self.TextColour, self.BackgroundColour)

		term.setCursorBlink(true)
		
		Current.CursorColour = self.TextColour
	end,

	Initialise = function(self, x, y, width, height, parent, text, backgroundColour, textColour, done, numerical)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		height = height or 1
		new.Width = width or #text + 2
		new.Height = height
		new.Y = y
		new.X = x
		new.TextInput = TextInput:Initialise(text or '', function(key)
			if done then
				done(key)
			end
			Draw()
		end, numerical)
		new.BackgroundColour = backgroundColour or colours.lightGrey
		new.TextColour = textColour or colours.black
		new.Parent = parent
		return new
	end,

	Click = function(self, side, x, y)
		Current.Input = self.TextInput
		self:Draw()
	end
}

TextInput = {
	Value = "",
	Change = nil,
	CursorPos = nil,
	Numerical = false,

	Initialise = function(self, value, change, numerical)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Value = value
		new.Change = change
		new.CursorPos = #value
		new.Numerical = numerical
		return new
	end,

	Char = function(self, char)
		if self.Numerical then
			char = tostring(tonumber(char))
		end
		if char == 'nil' then
			return
		end
		self.Value = string.sub(self.Value, 1, self.CursorPos ) .. char .. string.sub( self.Value, self.CursorPos + 1 )
		
		self.CursorPos = self.CursorPos + 1
		self.Change(key)
	end,

	Key = function(self, key)
		if key == keys.enter then
			self.Change(key)		
		elseif key == keys.left then
			-- Left
			if self.CursorPos > 0 then
				self.CursorPos = self.CursorPos - 1
				self.Change(key)
			end
			
		elseif key == keys.right then
			-- Right				
			if self.CursorPos < string.len(self.Value) then
				self.CursorPos = self.CursorPos + 1
				self.Change(key)
			end
		
		elseif key == keys.backspace then
			-- Backspace
			if self.CursorPos > 0 then
				self.Value = string.sub( self.Value, 1, self.CursorPos - 1 ) .. string.sub( self.Value, self.CursorPos + 1 )
				self.CursorPos = self.CursorPos - 1
			end
			self.Change(key)
		elseif key == keys.home then
			-- Home
			self.CursorPos = 0
			self.Change(key)
		elseif key == keys.delete then
			if self.CursorPos < string.len(self.Value) then
				self.Value = string.sub( self.Value, 1, self.CursorPos ) .. string.sub( self.Value, self.CursorPos + 2 )				
				self.Change(key)
			end
		elseif key == keys["end"] then
			-- End
			self.CursorPos = string.len(self.Value)
			self.Change(key)
		end
	end
}

LayerItem = {
	X = 1,
	Y = 1,
	Parent = nil,
	Layer = nil,

	Draw = function(self)
		self.Y = self.Layer.Index

		local pos = GetAbsolutePosition(self)

		local tc = colours.lightGrey

		if Current.Layer == self.Layer then
			tc = colours.white
		end

		Drawing.DrawBlankArea(pos.X, pos.Y, self.Width, self.Height, UIColours.Toolbar)
		
		Drawing.DrawCharacters(pos.X + 3, pos.Y, self.Layer.Name, tc, UIColours.Toolbar)

		if self.Layer.Visible then
			Drawing.DrawCharacters(pos.X + 1, pos.Y, "@", tc, UIColours.Toolbar)
		else
			Drawing.DrawCharacters(pos.X + 1, pos.Y, "X", tc, UIColours.Toolbar)
		end

	end,

	Initialise = function(self, layer, parent)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = parent.Width
		new.Height = 1
		new.Y = 1
		new.X = 1
		new.Layer = layer
		new.Parent = parent
		return new
	end,

	Click = function(self, side, x, y)
		if x == 2 then
			self.Layer.Visible = not self.Layer.Visible
		else
			Current.Layer = self.Layer
		end
		return true
	end
}

Menu = {
	X = 0,
	Y = 0,
	Width = 0,
	Height = 0,
	Owner = nil,
	Items = {},
	RemoveTop = false,

	Draw = function(self)
		Drawing.DrawBlankArea(self.X + 1, self.Y + 1, self.Width, self.Height, UIColours.Shadow)
		if not self.RemoveTop then
			Drawing.DrawBlankArea(self.X, self.Y, self.Width, self.Height, UIColours.MenuBackground)
			for i, item in ipairs(self.Items) do
				if item.Separator then
					Drawing.DrawArea(self.X, self.Y + i, self.Width, 1, '-', colours.grey, UIColours.MenuBackground)
				else
					local textColour = UIColours.MenuText
					if (item.Enabled and type(item.Enabled) == 'function' and item.Enabled() == false) or item.Enabled == false then
						textColour = UIColours.MenuDisabledText
					end
					Drawing.DrawCharacters(self.X + 1, self.Y + i, item.Title, textColour, UIColours.MenuBackground)
				end
			end
		else
			Drawing.DrawBlankArea(self.X, self.Y, self.Width, self.Height, UIColours.MenuBackground)
			for i, item in ipairs(self.Items) do
				if item.Separator then
					Drawing.DrawArea(self.X, self.Y + i - 1, self.Width, 1, '-', colours.grey, UIColours.MenuBackground)
				else
					local textColour = UIColours.MenuText
					if (item.Enabled and type(item.Enabled) == 'function' and item.Enabled() == false) or item.Enabled == false then
						textColour = UIColours.MenuDisabledText
					end
					Drawing.DrawCharacters(self.X + 1, self.Y + i - 1, item.Title, textColour, UIColours.MenuBackground)

					Drawing.DrawCharacters(self.X - 1 + self.Width-#item.KeyName, self.Y + i - 1, item.KeyName, textColour, UIColours.MenuBackground)
				end
			end
		end
	end,

	NameForKey = function(self, key)
		if key == keys.leftCtrl then
			return '^'
		elseif key == keys.tab then
			return 'Tab'
		elseif key == keys.delete then
			return 'Delete'
		elseif key == keys.n then
			return 'N'
		elseif key == keys.s then
			return 'S'
		elseif key == keys.o then
			return 'O'
		elseif key == keys.z then
			return 'Z'
		elseif key == keys.y then
			return 'Y'
		elseif key == keys.c then
			return 'C'
		elseif key == keys.x then
			return 'X'
		elseif key == keys.v then
			return 'V'
		elseif key == keys.r then
			return 'R'
		elseif key == keys.l then
			return 'L'
		elseif key == keys.t then
			return 'T'
		elseif key == keys.h then
			return 'H'
		elseif key == keys.e then
			return 'E'
		elseif key == keys.p then
			return 'P'
		elseif key == keys.f then
			return 'F'
		elseif key == keys.m then
			return 'M'
		else
			return '?'		
		end
	end,

	Initialise = function(self, x, y, items, owner, removeTop)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		if not owner then
			return
		end

		local keyNames = {}

		for i, v in ipairs(items) do
			items[i].KeyName = ''
			if v.Keys then
				for _i, key in ipairs(v.Keys) do
					items[i].KeyName = items[i].KeyName .. self:NameForKey(key)
				end
			end
			if items[i].KeyName ~= '' then
				table.insert(keyNames, items[i].KeyName)
			end
		end
		local keysLength = LongestString(keyNames)
		if keysLength > 0 then
			keysLength = keysLength + 2
		end

		new.Width = LongestString(items, 'Title') + 2 + keysLength
		if new.Width < 10 then
			new.Width = 10
		end
		new.Height = #items + 2
		new.RemoveTop = removeTop or false
		if removeTop then
			new.Height = new.Height - 1
		end
		
		if y < 1 then
			y = 1
		end
		if x < 1 then
			x = 1
		end

		if y + new.Height > Drawing.Screen.Height + 1 then
			y = Drawing.Screen.Height - new.Height
		end
		if x + new.Width > Drawing.Screen.Width + 1 then
			x = Drawing.Screen.Width - new.Width
		end


		new.Y = y
		new.X = x
		new.Items = items
		new.Owner = owner
		return new
	end,

	New = function(self, x, y, items, owner, removeTop)
		if Current.Menu and Current.Menu.Owner == owner then
			Current.Menu = nil
			return
		end

		local new = self:Initialise(x, y, items, owner, removeTop)
		Current.Menu = new
		return new
	end,

	Click = function(self, side, x, y)
		local i = y-1
		if self.RemoveTop then
			i = y
		end
		if i >= 1 and y < self.Height then
			if not ((self.Items[i].Enabled and type(self.Items[i].Enabled) == 'function' and self.Items[i].Enabled() == false) or self.Items[i].Enabled == false) and self.Items[i].Click then
				self.Items[i]:Click()
				if Current.Menu.Owner and Current.Menu.Owner.Toggle then
					Current.Menu.Owner.Toggle = false
				end
				Current.Menu = nil
				self = nil
			end
			return true
		end
	end
}

MenuBar = {
	X = 1,
	Y = 1,
	Width = Drawing.Screen.Width,
	Height = 1,
	MenuBarItems = {},

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		--Drawing.DrawArea(self.X - 1, self.Y, 1, self.Height, "|", UIColours.ToolbarText, UIColours.Background)

		Drawing.DrawBlankArea(self.X, self.Y, self.Width, self.Height, UIColours.Toolbar)
		for i, button in ipairs(self.MenuBarItems) do
			button:Draw()
		end
	end,

	Initialise = function(self, items)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.X = 1
		new.Y = 1
		new.MenuBarItems = items
		return new
	end,

	AddToolbarItem = function(self, item)
		table.insert(self.ToolbarItems, item)
		self:CalculateToolbarItemPositions()
	end,

	CalculateToolbarItemPositions = function(self)
		local currY = 1
		for i, toolbarItem in ipairs(self.ToolbarItems) do
			toolbarItem.Y = currY
			currY = currY + toolbarItem.Height
		end
	end,

	Click = function(self, side, x, y)
		for i, item in ipairs(self.MenuBarItems) do
			if item.X <= x and item.X + item.Width > x then
				if item:Click(item, side, x - item.X + 1, 1) then
					break
				end
			end
		end
		return false
	end
}

--Modules--

Modules = {
	{
		Title = "Colours",
		ToolbarItem = nil,
		Initialise = function(self)
			self.ToolbarItem = ToolbarItem:Initialise(self, nil, true, Current.Toolbar)

			local buttons = {}

			local i = 0

			local coloursWidth = 8
			local _colours = {
				colours.brown,
				colours.yellow,
				colours.orange,
				colours.red,
				colours.green,
				colours.lime,
				colours.magenta,
				colours.pink,
				colours.purple,
				colours.blue,
				colours.cyan,
				colours.lightBlue,
				colours.lightGrey,
				colours.grey,
				colours.black,
				colours.white
			}

			for k, colour in pairs(_colours) do
				if type(colour) == 'number' and colour ~= -1 then
					i = i + 1

					local y = math.floor(i/(coloursWidth/2))

					local x = (i%(coloursWidth/2))
					if x == 0 then
						x = (coloursWidth/2)
						y = y -1
					end

					table.insert(buttons,
						{
							X = x*2 - 2 + self.ToolbarItem.Width - coloursWidth,
							Y = y+1,
							Width = 2,
							Height = 1,
							BackgroundColour = colour,
							Click = function(self, side, x, y)
								SetColour(self.BackgroundColour)
							end
						}
					)
				end
			end

			for i, button in ipairs(buttons) do
				table.insert(self.ToolbarItem.ContentView.Views, 
					Button:Initialise(button.X, button.Y, button.Width, button.Height, button.BackgroundColour, self.ToolbarItem.ContentView, button.Click))	
			end
			
			table.insert(self.ToolbarItem.ContentView.Views, 
					Button:Initialise(1, 1, 4, 3, function()return Current.Colour end, self.ToolbarItem.ContentView, nil))
		
			Current.Toolbar:AddToolbarItem(self.ToolbarItem)
		end
	},

	{
		Title = "Tools",
		ToolbarItem = nil,
		Update = function(self)
			for i, view in ipairs(self.ToolbarItem.ContentView.Views) do
				if (Current.Tool and Current.Tool.Name == view.Text) then
					view.TextColour = colours.white
				else
					view.TextColour = colours.lightGrey
				end
			end
			self.ToolbarItem.ContentView.Views[1].Text = 'Size: '..Current.ToolSize
		end,

		Initialise = function(self)
			self.ToolbarItem = ToolbarItem:Initialise(self, #Tools+2, true, Current.Toolbar,
				{{
					Title = "Change Tool Size",
					Click = function()
						DisplayToolSizeWindow()
					end,
				}})

			table.insert(self.ToolbarItem.ContentView.Views, Button:Initialise(1, 1, self.ToolbarItem.Width, 1, UIColours.Toolbar, self.ToolbarItem.ContentView, DisplayToolSizeWindow, 'Size: '..Current.ToolSize))

			local y = 2
			for i, tool in ipairs(Tools) do
				table.insert(self.ToolbarItem.ContentView.Views, Button:Initialise(1, y, self.ToolbarItem.Width, 1, UIColours.Toolbar, self.ToolbarItem.ContentView, function() SetTool(tool) self:Update(self.ToolbarItem) end, tool.Name))
				y = y + 1
			end

			self:Update(self.ToolbarItem)

			Current.Toolbar:AddToolbarItem(self.ToolbarItem)
		end
	},

	{
		Title = "Layers",
		ToolbarItem = nil,
		Update = function(self)
			if Current.Artboard then
				self.ToolbarItem.ContentView.Views = {}
				for i = 1, #Current.Artboard.Layers do
					table.insert(self.ToolbarItem.ContentView.Views, LayerItem:Initialise(Current.Artboard.Layers[#Current.Artboard.Layers-i+1], self.ToolbarItem.ContentView))
				end					
			end
		end,

		Initialise = function(self)
			self.ToolbarItem = ToolbarItem:Initialise(self, nil, true, Current.Toolbar,
				{{
					Title = "New Layer",
					Click = function()
						MakeNewLayer()
					end,
					Enabled = function()
						return CheckOpenArtboard()
					end
				},
				{
					Title = 'Delete Layer',
					Click = function()
						DeleteLayer()
					end,
					Enabled = function()
						return CheckSelectedLayer()
					end
				},
				{
					Title = 'Rename Layer...',
					Click = function()
						RenameLayer()
					end,
					Enabled = function()
						return CheckSelectedLayer()
					end
				}})
			
			self:Update()

			Current.Toolbar:AddToolbarItem(self.ToolbarItem)
		end
	}

}

function ModuleNamed(name)
	for i, v in ipairs(Modules) do
		if v.Title == name then
			return v
		end
	end
end

--Tools--

function ToolAffectedPixels(x, y)
	if not CheckSelectedLayer() then
		return {}
	end
	if Current.ToolSize == 1 then
		if Current.Layer.Pixels[x] and Current.Layer.Pixels[x][y] then
			return {{Current.Layer.Pixels[x][y], x, y}}
		end
	else
		local pixels = {}
		local cornerX = x - math.ceil(Current.ToolSize/2)
		local cornerY = y - math.ceil(Current.ToolSize/2)
		for _x = 1, Current.ToolSize do
			for _y = 1, Current.ToolSize do
				if Current.Layer.Pixels[cornerX + _x] and Current.Layer.Pixels[cornerX + _x][cornerY + _y] then
					table.insert(pixels, {Current.Layer.Pixels[cornerX + _x][cornerY + _y], cornerX + _x, cornerY + _y})
				end
			end
		end
		return pixels
	end
end
local moveStartPoint = {}
Tools = {
	{
		Name = "Hand",
		Use = function(self, x, y, side, drag)
			Current.Input = nil
			if drag and Current.HandDragStart and Current.HandDragStart[1] and Current.HandDragStart[2] then
				local deltaX = x - Current.HandDragStart[1]
				local deltaY = y - Current.HandDragStart[2]
				Current.Artboard.X = Current.Artboard.X + deltaX
				Current.Artboard.Y = Current.Artboard.Y + deltaY
			else
				Current.HandDragStart = {x, y}
			end
			sleep(0)
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Pencil",
		Use = function(self, _x, _y, side, artboard)
			Current.Input = nil
			for i, pixel in ipairs(ToolAffectedPixels(_x, _y)) do
				if side == 1 then
					pixel[1].BackgroundColour = Current.Colour
				elseif side == 2 then
					pixel[1].TextColour = Current.Colour
				end
				pixel[1]:Draw(pixel[2], pixel[3])
			end
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Eraser",
		Use = function(self, x, y, side)
			Current.Input = nil
			Current.Layer:SetPixel(x, y, nil, Current.Layer.BackgroundColour, nil)
			for i, pixel in ipairs(ToolAffectedPixels(x, y)) do
				Current.Layer:SetPixel(pixel[2], pixel[3], nil, Current.Layer.BackgroundColour, nil)
			end
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Fill Bucket",
		Use = function(self, x, y, side)
			local replaceColour = Current.Layer.Pixels[x][y].BackgroundColour
			if side == 2 then
				replaceColour = Current.Layer.Pixels[x][y].TextColour
			end

			local nodes = {{X = x, Y = y}}

			while #nodes > 0 do
				local node = nodes[1]
				if Current.Layer.Pixels[node.X] and Current.Layer.Pixels[node.X][node.Y] then
					local replacing = Current.Layer.Pixels[node.X][node.Y].BackgroundColour
					if side == 2 then
						replacing = Current.Layer.Pixels[node.X][node.Y].TextColour
					end
					if replacing == replaceColour and replacing ~= Current.Colour then
						if side == 1 then
							Current.Layer.Pixels[node.X][node.Y].BackgroundColour = Current.Colour
						elseif side == 2 then
							Current.Layer.Pixels[node.X][node.Y].TextColour = Current.Colour
						end
						table.insert(nodes, {X = node.X, Y = node.Y + 1})
						table.insert(nodes, {X = node.X + 1, Y = node.Y})
						if x > 1 then
							table.insert(nodes, {X = node.X - 1, Y = node.Y})
						end
						if y > 1 then
							table.insert(nodes, {X = node.X, Y = node.Y - 1})
						end
					end
				end
				table.remove(nodes, 1)
			end
			Draw()
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Select",
		Use = function(self, x, y, side, drag)
			Current.Input = nil
			if not drag then
				Current.Selection[1] = vector.new(x, y, 0)
				Current.Selection[2] = nil
			else
				Current.Selection[2] = vector.new(x, y, 0)
			end
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Move",
		Use = function(self, x, y, side, drag)
			Current.Input = nil

			if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
				if drag and moveStartPoint then
					local pixels = Current.Layer:PixelsInSelection(true)
					local size = Current.Selection[1] - Current.Selection[2]
					Current.Selection[1] = vector.new(x-moveStartPoint[1], y-moveStartPoint[2], 0)
					Current.Selection[2] = vector.new(x-moveStartPoint[1]-size.x, y-moveStartPoint[2]-size.y, 0)
					Current.Layer:InsertPixels(pixels)
				else
					moveStartPoint = {x-Current.Selection[1].x, y-Current.Selection[1].y}
				end
			end
		end,
		Select = function(self)
			return true
		end
	},

	{
		Name = "Text",
		Use = function(self, x, y)
			Current.Input = TextInput:Initialise('', function(key)
				if key == keys.delete or key == keys.backspace then
					if #Current.Input.Value == 0 then
						if Current.Layer.Pixels[x] and Current.Layer.Pixels[x][y] then
							Current.Layer.Pixels[x][y]:Set(nil, nil, ' ')
							local newPos = Current.CursorPos[1] - Current.Artboard.X
							if newPos < Current.Artboard.X - 1 then
								newPos = Current.Artboard.X - 1
							end
							Current.Tool:Use(newPos, Current.CursorPos[2] - Current.Artboard.Y + 1)
							Draw()
						end
						return
					else
						if Current.Layer.Pixels[x+#Current.Input.Value] and Current.Layer.Pixels[x+#Current.Input.Value][y] then
							Current.Layer.Pixels[x+#Current.Input.Value][y]:Set(nil, nil, ' ')
						end
					end
				else
					local i = #Current.Input.Value
					if Current.Layer.Pixels[x+i-1] then
						Current.Layer.Pixels[x+i-1][y]:Set(Current.Colour, nil, Current.Input.Value:sub(i,i))
						Current.Layer.Pixels[x+i-1][y]:Draw(x+i-1, y)
					end
				end

				local newPos = x+Current.Input.CursorPos

				if newPos > Current.Artboard.Width then
					Current.Input.CursorPos = Current.Input.CursorPos - 1
				end

				Current.CursorPos = {x+Current.Input.CursorPos + Current.Artboard.X - 1, y + Current.Artboard.Y - 1}
				Current.CursorColour = Current.Colour
				Draw()
			end)

			Current.CursorPos = {x + Current.Artboard.X - 1, y + Current.Artboard.Y - 1}
			Current.CursorColour = Current.Colour
		end,
		Select = function(self)
			if Current.Artboard.Format == '.nfp' then
				ButtonDialougeWindow:Initialise('NFP does not support text!', 'The format you are using, NFP, does not support text. Use NFT or SKCH to use text.', 'Ok', nil, function(window)
					window:Close()
				end):Show()
				return false
			else
				return true
			end
		end
	}
}


function ToolNamed(name)
	for i, v in ipairs(Tools) do
		if v.Name == name then
			return v
		end
	end
end

--Windows--

NewDocumentWindow = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	CursorPos = 1,
	Visible = true,
	Return = nil,
	OkButton = nil,
	Format = '.skch',
	ImageBackgroundColour = colours.white,
	NameLabelHighlight = false,
	SizeLabelHighlight = false,


	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		if not self.Visible then
			return
		end
		Drawing.DrawBlankArea(self.X + 1, self.Y+1, self.Width, self.Height, colours.grey)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 1, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y+1, self.Width, self.Height-1, colours.white)
		Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, 1, self.Title, colours.black, colours.lightGrey)

		local nameLabelColour = colours.black
		if self.NameLabelHighlight then
			nameLabelColour = colours.red
		end

		Drawing.DrawCharacters(self.X+1, self.Y+2, "Name", nameLabelColour, colours.white)
		Drawing.DrawCharacters(self.X+1, self.Y+4, "Type", colours.black, colours.white)

		local sizeLabelColour = colours.black
		if self.SizeLabelHighlight then
			sizeLabelColour = colours.red
		end
		Drawing.DrawCharacters(self.X+1, self.Y+6, "Size", sizeLabelColour, colours.white)
		Drawing.DrawCharacters(self.X+11, self.Y+6, "x", colours.black, colours.white)
		Drawing.DrawCharacters(self.X+1, self.Y+8, "Background", colours.black, colours.white)

		self.OkButton:Draw()
		self.CancelButton:Draw()
		self.SKCHButton:Draw()
		self.NFTButton:Draw()
		self.NFPButton:Draw()
		self.PathTextBox:Draw()
		self.WidthTextBox:Draw()
		self.HeightTextBox:Draw()
		self.WhiteButton:Draw()
		self.BlackButton:Draw()
		self.TransparentButton:Draw()
	end,	

	Initialise = function(self, returnFunc)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = 32
		new.Height = 13
		new.Return = returnFunc
		new.X = math.ceil((Drawing.Screen.Width - new.Width) / 2)
		new.Y = math.ceil((Drawing.Screen.Height - new.Height) / 2)
		new.Title = 'New Document'
		new.Visible = true
		new.NameLabelHighlight = false
		new.SizeLabelHighlight = false
		new.Format = '.skch'
		new.OkButton = Button:Initialise(new.Width - 4, new.Height - 1, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			local path = new.PathTextBox.TextInput.Value
			local ok = true
			new.NameLabelHighlight = false
			new.SizeLabelHighlight = false
			local _fs = fs
			if OneOS then
				_fs = OneOS.FS
			end
			if path:sub(-1) == '/' or _fs.isDir(path) or #path == 0 then
				ok = false
				new.NameLabelHighlight = true
			end

			if #new.WidthTextBox.TextInput.Value == 0 or tonumber(new.WidthTextBox.TextInput.Value) <= 0 then
				ok = false
				new.SizeLabelHighlight = true
			end

			if #new.HeightTextBox.TextInput.Value == 0 or tonumber(new.HeightTextBox.TextInput.Value) <= 0 then
				ok = false
				new.SizeLabelHighlight = true
			end

			if ok then
				returnFunc(new, true, path, tonumber(new.WidthTextBox.TextInput.Value), tonumber(new.HeightTextBox.TextInput.Value), new.Format, new.ImageBackgroundColour)
			else
				Draw()
			end
		end, 'Ok', colours.black)
		new.CancelButton = Button:Initialise(new.Width - 13, new.Height - 1, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)returnFunc(new, false)end, 'Cancel', colours.black)

		new.SKCHButton = Button:Initialise(7, 5, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.NFTButton.Toggle = false
			new.NFPButton.Toggle = false
			self.Toggle = false
			new.Format = '.skch'
		end, '.skch', colours.black, true, colours.lightBlue)
		new.NFTButton = Button:Initialise(15, 5, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.SKCHButton.Toggle = false
			new.NFPButton.Toggle = false
			self.Toggle = false
			new.Format = '.nft'
		end, '.nft', colours.black, false, colours.lightBlue)
		new.NFPButton = Button:Initialise(22, 5, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.SKCHButton.Toggle = false
			new.NFTButton.Toggle = false
			self.Toggle = false
			new.Format = '.nfp'
		end, '.nfp', colours.black, false, colours.lightBlue)

		local path = ''
		if OneOS then
			path = '/Desktop/'
		end
		new.PathTextBox = TextBox:Initialise(7, 3, new.Width - 7, 1, new, path, nil, nil, function(key)
			if key == keys.enter or key == keys.tab then
				Current.Input = new.WidthTextBox.TextInput
			end			
		end)
		new.WidthTextBox = TextBox:Initialise(7, 7, 4, 1, new, tostring(15), nil, nil, function()
			if key == keys.enter or key == keys.tab then
				Current.Input = new.HeightTextBox.TextInput
			end
		end, true)
		new.HeightTextBox = TextBox:Initialise(14, 7, 4, 1, new, tostring(10), nil, nil, function()
			if key == keys.enter or key == keys.tab then
				Current.Input = new.PathTextBox.TextInput
			end
		end, true)
		Current.Input = new.PathTextBox.TextInput


		new.WhiteButton = Button:Initialise(2, 10, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.TransparentButton.Toggle = false
			new.BlackButton.Toggle = false
			self.Toggle = false
			new.ImageBackgroundColour = colours.white
		end, 'White', colours.black, true, colours.lightBlue)
		new.BlackButton = Button:Initialise(10, 10, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.TransparentButton.Toggle = false
			new.WhiteButton.Toggle = false
			self.Toggle = false
			new.ImageBackgroundColour = colours.black
		end, 'Black', colours.black, false, colours.lightBlue)
		new.TransparentButton = Button:Initialise(18, 10, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			new.WhiteButton.Toggle = false
			new.BlackButton.Toggle = false
			self.Toggle = false
			new.ImageBackgroundColour = colours.transparent
		end, 'Transparent', colours.black, false, colours.lightBlue)

		return new
	end,

	Show = function(self)
		Current.Window = self
		return self
	end,

	Close = function(self)
		Current.Input = nil
		Current.Window = nil
		self = nil
	end,

	Flash = function(self)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
		sleep(0.15)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
	end,

	ButtonClick = function(self, button, x, y)
		if button.X <= x and button.Y <= y and button.X + button.Width > x and button.Y + button.Height > y then
			button:Click()
		end
	end,

	Click = function(self, side, x, y)
		local items = {self.OkButton, self.CancelButton, self.SKCHButton, self.NFTButton, self.NFPButton, self.PathTextBox, self.WidthTextBox, self.HeightTextBox, self.WhiteButton, self.BlackButton, self.TransparentButton}
		for i, v in ipairs(items) do
			if CheckClick(v, x, y) then
				v:Click(side, x, y)
			end
		end
		return true
	end
}

local TidyPath = function(path)
	path = '/'..path
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	if _fs.isDir(path) then
		path = path .. '/'
	end

	path, n = path:gsub("//", "/")
	while n > 0 do
		path, n = path:gsub("//", "/")
	end
	return path
end

local WrapText = function(text, maxWidth)
	local lines = {''}
    for word, space in text:gmatch('(%S+)(%s*)') do
            local temp = lines[#lines] .. word .. space:gsub('\n','')
            if #temp > maxWidth then
                    table.insert(lines, '')
            end
            if space:find('\n') then
                    lines[#lines] = lines[#lines] .. word
                    
                    space = space:gsub('\n', function()
                            table.insert(lines, '')
                            return ''
                    end)
            else
                    lines[#lines] = lines[#lines] .. word .. space
            end
    end
	return lines
end

OpenDocumentWindow = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	CursorPos = 1,
	Visible = true,
	Return = nil,
	OpenButton = nil,
	PathTextBox = nil,
	CurrentDirectory = '/',
	Scroll = 0,
	MaxScroll = 0,
	GoUpButton = nil,
	SelectedFile = '',
	Files = {},
	Typed = false,

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		if not self.Visible then
			return
		end
		Drawing.DrawBlankArea(self.X + 1, self.Y+1, self.Width, self.Height, colours.grey)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 3, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y+1, self.Width, self.Height-6, colours.white)
		Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, 1, self.Title, colours.black, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y + self.Height - 5, self.Width, 5, colours.lightGrey)
		self:DrawFiles()

		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		if (_fs.exists(self.PathTextBox.TextInput.Value)) or (self.SelectedFile and #self.SelectedFile > 0 and _fs.exists(self.CurrentDirectory .. self.SelectedFile)) then
			self.OpenButton.TextColour = colours.black
		else
			self.OpenButton.TextColour = colours.lightGrey
		end

		self.PathTextBox:Draw()
		self.OpenButton:Draw()
		self.CancelButton:Draw()
		self.GoUpButton:Draw()
	end,

	DrawFiles = function(self)
		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		for i, file in ipairs(self.Files) do
			if i > self.Scroll and i - self.Scroll <= 11 then
				if file == self.SelectedFile then
					Drawing.DrawCharacters(self.X + 1, self.Y + i - self.Scroll, file, colours.white, colours.lightBlue)
				elseif string.find(file, '%.skch') or string.find(file, '%.nft') or string.find(file, '%.nfp') or _fs.isDir(self.CurrentDirectory .. file) then
					Drawing.DrawCharacters(self.X + 1, self.Y + i - self.Scroll, file, colours.black, colours.white)
				else
					Drawing.DrawCharacters(self.X + 1, self.Y + i - self.Scroll, file, colours.grey, colours.white)
				end
			end
		end
		self.MaxScroll = #self.Files - 11
		if self.MaxScroll < 0 then
			self.MaxScroll = 0
		end
	end,

	Initialise = function(self, returnFunc)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = 32
		new.Height = 17
		new.Return = returnFunc
		new.X = math.ceil((Drawing.Screen.Width - new.Width) / 2)
		new.Y = math.ceil((Drawing.Screen.Height - new.Height) / 2)
		new.Title = 'Open Document'
		new.Visible = true
		new.CurrentDirectory = '/'
		new.SelectedFile = nil
		if OneOS then
			new.CurrentDirectory = '/Desktop/'
		end
		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		new.OpenButton = Button:Initialise(new.Width - 6, new.Height - 1, nil, nil, colours.white, new, function(self, side, x, y, toggle)
			if _fs.exists(new.PathTextBox.TextInput.Value) and self.TextColour == colours.black and not _fs.isDir(new.PathTextBox.TextInput.Value) then
				returnFunc(new, true, TidyPath(new.PathTextBox.TextInput.Value))
			elseif new.SelectedFile and self.TextColour == colours.black and _fs.isDir(new.CurrentDirectory .. new.SelectedFile) then
				new:GoToDirectory(new.CurrentDirectory .. new.SelectedFile)
			elseif new.SelectedFile and self.TextColour == colours.black then
				returnFunc(new, true, TidyPath(new.CurrentDirectory .. '/' .. new.SelectedFile))
			end
		end, 'Open', colours.black)
		new.CancelButton = Button:Initialise(new.Width - 15, new.Height - 1, nil, nil, colours.white, new, function(self, side, x, y, toggle)
			returnFunc(new, false)
		end, 'Cancel', colours.black)
		new.GoUpButton = Button:Initialise(2, new.Height - 1, nil, nil, colours.white, new, function(self, side, x, y, toggle)
			local folderName = _fs.getName(new.CurrentDirectory)
			local parentDirectory = new.CurrentDirectory:sub(1, #new.CurrentDirectory-#folderName-1)
			new:GoToDirectory(parentDirectory)
		end, 'Go Up', colours.black)
		new.PathTextBox = TextBox:Initialise(2, new.Height - 3, new.Width - 2, 1, new, new.CurrentDirectory, colours.white, colours.black)
		new:GoToDirectory(new.CurrentDirectory)
		return new
	end,

	Show = function(self)
		Current.Window = self
		return self
	end,

	Close = function(self)
		Current.Input = nil
		Current.Window = nil
		self = nil
	end,

	GoToDirectory = function(self, path)
		path = TidyPath(path)
		self.CurrentDirectory = path
		self.Scroll = 0
		self.SelectedFile = nil
		self.Typed = false
		self.PathTextBox.TextInput.Value = path
		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		self.Files = _fs.list(self.CurrentDirectory)
		Draw()
	end,

	Flash = function(self)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
		sleep(0.15)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
	end,

	Click = function(self, side, x, y)
		local items = {self.OpenButton, self.CancelButton, self.PathTextBox, self.GoUpButton}
		local found = false
		for i, v in ipairs(items) do
			if CheckClick(v, x, y) then
				v:Click(side, x, y)
				found = true
			end
		end

		if not found then
			if y <= 12 then
				local _fs = fs
				if OneOS then
					_fs = OneOS.FS
				end
				self.SelectedFile = _fs.list(self.CurrentDirectory)[y-1]
				self.PathTextBox.TextInput.Value = TidyPath(self.CurrentDirectory .. '/' .. self.SelectedFile)
				Draw()
			end
		end
		return true
	end
}

ButtonDialougeWindow = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	CursorPos = 1,
	Visible = true,
	CancelButton = nil,
	OkButton = nil,
	Lines = {},

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		if not self.Visible then
			return
		end
		Drawing.DrawBlankArea(self.X + 1, self.Y+1, self.Width, self.Height, colours.grey)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 1, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y+1, self.Width, self.Height-1, colours.white)
		Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, 1, self.Title, colours.black, colours.lightGrey)

		for i, text in ipairs(self.Lines) do
			Drawing.DrawCharacters(self.X + 1, self.Y + 1 + i, text, colours.black, colours.white)
		end

		self.OkButton:Draw()
		if self.CancelButton then
			self.CancelButton:Draw()
		end
	end,

	Initialise = function(self, title, message, okText, cancelText, returnFunc)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = 28
		new.Lines = WrapText(message, new.Width - 2)
		new.Height = 5 + #new.Lines
		new.Return = returnFunc
		new.X = math.ceil((Drawing.Screen.Width - new.Width) / 2)
		new.Y = math.ceil((Drawing.Screen.Height - new.Height) / 2)
		new.Title = title
		new.Visible = true
		new.Visible = true
		new.OkButton = Button:Initialise(new.Width - #okText - 2, new.Height - 1, nil, 1, nil, new, function()
			returnFunc(new, true)
		end, okText)
		if cancelText then
			new.CancelButton = Button:Initialise(new.Width - #okText - 2 - 1 - #cancelText - 2, new.Height - 1, nil, 1, nil, new, function()
				returnFunc(new, false)
			end, cancelText)
		end

		return new
	end,

	Show = function(self)
		Current.Window = self
		return self
	end,

	Close = function(self)
		Current.Window = nil
		self = nil
	end,

	Flash = function(self)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
		sleep(0.15)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
	end,

	Click = function(self, side, x, y)
		local items = {self.OkButton, self.CancelButton}
		local found = false
		for i, v in ipairs(items) do
			if CheckClick(v, x, y) then
				v:Click(side, x, y)
				found = true
			end
		end
		return true
	end
}

TextDialougeWindow = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	CursorPos = 1,
	Visible = true,
	CancelButton = nil,
	OkButton = nil,
	Lines = {},
	TextInput = nil,

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		if not self.Visible then
			return
		end
		Drawing.DrawBlankArea(self.X + 1, self.Y+1, self.Width, self.Height, colours.grey)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 1, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y+1, self.Width, self.Height-1, colours.white)
		Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, 1, self.Title, colours.black, colours.lightGrey)

		for i, text in ipairs(self.Lines) do
			Drawing.DrawCharacters(self.X + 1, self.Y + 1 + i, text, colours.black, colours.white)
		end


		Drawing.DrawBlankArea(self.X + 1, self.Y + self.Height - 4, self.Width - 2, 1, colours.lightGrey)
		Drawing.DrawCharacters(self.X + 2, self.Y + self.Height - 4, self.TextInput.Value, colours.black, colours.lightGrey)
		Current.CursorPos = {self.X + 2 + self.TextInput.CursorPos, self.Y + self.Height - 4}
		Current.CursorColour = colours.black

		self.OkButton:Draw()
		if self.CancelButton then
			self.CancelButton:Draw()
		end
	end,

	Initialise = function(self, title, message, okText, cancelText, returnFunc, numerical)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = 28
		new.Lines = WrapText(message, new.Width - 2)
		new.Height = 7 + #new.Lines
		new.Return = returnFunc
		new.X = math.ceil((Drawing.Screen.Width - new.Width) / 2)
		new.Y = math.ceil((Drawing.Screen.Height - new.Height) / 2)
		new.Title = title
		new.Visible = true
		new.Visible = true
		new.OkButton = Button:Initialise(new.Width - #okText - 2, new.Height - 1, nil, 1, nil, new, function()
			if #new.TextInput.Value > 0 then
				returnFunc(new, true, new.TextInput.Value)
			end
		end, okText)
		if cancelText then
			new.CancelButton = Button:Initialise(new.Width - #okText - 2 - 1 - #cancelText - 2, new.Height - 1, nil, 1, nil, new, function()
				returnFunc(new, false)
			end, cancelText)
		end
		new.TextInput = TextInput:Initialise('', function(enter)
			if enter then
				new.OkButton:Click()
			end
			Draw()
		end, numerical)

		Current.Input = new.TextInput

		return new
	end,

	Show = function(self)
		Current.Window = self
		return self
	end,

	Close = function(self)
		Current.Window = nil
		Current.Input = nil
		self = nil
	end,

	Flash = function(self)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
		sleep(0.15)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
	end,

	Click = function(self, side, x, y)
		local items = {self.OkButton, self.CancelButton}
		local found = false
		for i, v in ipairs(items) do
			if CheckClick(v, x, y) then
				v:Click(side, x, y)
				found = true
			end
		end
		return true
	end
}

ResizeDocumentWindow = {
	X = 1,
	Y = 1,
	Width = 0,
	Height = 0,
	CursorPos = 1,
	Visible = true,
	Return = nil,
	OkButton = nil,
	AnchorPosition = 5,
	WidthLabelHighlight = false,
	HeightLabelHighlight = false,

	AbsolutePosition = function(self)
		return {X = self.X, Y = self.Y}
	end,

	Draw = function(self)
		if not self.Visible then
			return
		end
		Drawing.DrawBlankArea(self.X + 1, self.Y+1, self.Width, self.Height, colours.grey)
		Drawing.DrawBlankArea(self.X, self.Y, self.Width, 1, colours.lightGrey)
		Drawing.DrawBlankArea(self.X, self.Y+1, self.Width, self.Height-1, colours.white)
		Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, 1, self.Title, colours.black, colours.lightGrey)

		Drawing.DrawCharacters(self.X+1, self.Y+2, "New Size", colours.lightGrey, colours.white)
		if (#self.WidthTextBox.TextInput.Value > 0 and tonumber(self.WidthTextBox.TextInput.Value) < Current.Artboard.Width) or (#self.HeightTextBox.TextInput.Value > 0 and tonumber(self.HeightTextBox.TextInput.Value) < Current.Artboard.Height) then
			Drawing.DrawCharacters(self.X+1, self.Y+8, "Clipping will occur!", colours.red, colours.white)
		end

		local widthLabelColour = colours.black
		if self.WidthLabelHighlight then
			widthLabelColour = colours.red
		end
		
		local heightLabelColour = colours.black
		if self.HeightLabelHighlight then
			heightLabelColour = colours.red
		end

		Drawing.DrawCharacters(self.X+1, self.Y+4, "Width", widthLabelColour, colours.white)
		Drawing.DrawCharacters(self.X+1, self.Y+6, "Height", heightLabelColour, colours.white)

		Drawing.DrawCharacters(self.X+14, self.Y+2, "Anchor", colours.lightGrey, colours.white)

		self.WidthTextBox:Draw()
		self.HeightTextBox:Draw()
		self.OkButton:Draw()
		self.Anchor1:Draw()
		self.Anchor2:Draw()
		self.Anchor3:Draw()
		self.Anchor4:Draw()
		self.Anchor5:Draw()
		self.Anchor6:Draw()
		self.Anchor7:Draw()
		self.Anchor8:Draw()
		self.Anchor9:Draw()
	end,	

	Initialise = function(self, returnFunc)
		local new = {}    -- the new instance
		setmetatable( new, {__index = self} )
		new.Width = 27
		new.Height = 10
		new.Return = returnFunc
		new.X = math.ceil((Drawing.Screen.Width - new.Width) / 2)
		new.Y = math.ceil((Drawing.Screen.Height - new.Height) / 2)
		new.Title = 'Resize Document'
		new.Visible = true

		new.WidthTextBox = TextBox:Initialise(9, 5, 4, 1, new, tostring(Current.Artboard.Width), nil, nil, function()
			new:UpdateAnchorButtons()
		end, true)
		new.HeightTextBox = TextBox:Initialise(9, 7, 4, 1, new, tostring(Current.Artboard.Height), nil, nil, function()
			new:UpdateAnchorButtons()
		end, true)
		new.OkButton = Button:Initialise(new.Width - 4, new.Height - 1, nil, nil, colours.lightGrey, new, function(self, side, x, y, toggle)
			local ok = true
			new.WidthLabelHighlight = false
			new.HeightLabelHighlight = false

			if #new.WidthTextBox.TextInput.Value == 0 or tonumber(new.WidthTextBox.TextInput.Value) <= 0 then
				ok = false
				new.WidthLabelHighlight = true
			end

			if #new.HeightTextBox.TextInput.Value == 0 or tonumber(new.HeightTextBox.TextInput.Value) <= 0 then
				ok = false
				new.HeightLabelHighlight = true
			end

			if ok then
				returnFunc(new, tonumber(new.WidthTextBox.TextInput.Value), tonumber(new.HeightTextBox.TextInput.Value), new.AnchorPosition)
			else
				Draw()
			end
		end, 'Ok', colours.black)

		local anchorX = 15
		local anchorY = 5
		new.Anchor1 = Button:Initialise(anchorX, anchorY, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 1 new:UpdateAnchorButtons() end, ' ', colours.black)
		new.Anchor2 = Button:Initialise(anchorX+1, anchorY, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 2 new:UpdateAnchorButtons() end, '^', colours.black)
		new.Anchor3 = Button:Initialise(anchorX+2, anchorY, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 3 new:UpdateAnchorButtons() end, ' ', colours.black)
		new.Anchor4 = Button:Initialise(anchorX, anchorY+1, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 4 new:UpdateAnchorButtons() end, '<', colours.black)
		new.Anchor5 = Button:Initialise(anchorX+1, anchorY+1, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 5 new:UpdateAnchorButtons() end, '#', colours.black)
		new.Anchor6 = Button:Initialise(anchorX+2, anchorY+1, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 6 new:UpdateAnchorButtons() end, '>', colours.black)
		new.Anchor7 = Button:Initialise(anchorX, anchorY+2, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 7 new:UpdateAnchorButtons() end, ' ', colours.black)
		new.Anchor8 = Button:Initialise(anchorX+1, anchorY+2, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 8 new:UpdateAnchorButtons() end, 'v', colours.black)
		new.Anchor9 = Button:Initialise(anchorX+2, anchorY+2, 1, 1, colours.lightGrey, new, function(self, side, x, y, toggle)new.AnchorPosition = 9 new:UpdateAnchorButtons() end, ' ', colours.black)

		return new
	end,

	UpdateAnchorButtons = function(self)
		local anchor1 = ' '
		local anchor2 = ' '
		local anchor3 = ' '
		local anchor4 = ' '
		local anchor5 = ' '
		local anchor6 = ' '
		local anchor7 = ' '
		local anchor8 = ' '
		local anchor9 = ' '
		self.AnchorPosition = self.AnchorPosition or 5
		if self.AnchorPosition == 1 then
			anchor1 = '#'
			anchor2 = '>'
			anchor4 = 'v'
		elseif self.AnchorPosition == 2 then
			anchor1 = '<'
			anchor2 = '#'
			anchor3 = '>'
			anchor5 = 'v'
		elseif self.AnchorPosition == 3 then
			anchor2 = '<'
			anchor3 = '#'
			anchor6 = 'v'
		elseif self.AnchorPosition == 4 then
			anchor1 = '^'
			anchor4 = '#'
			anchor5 = '>'
			anchor7 = 'v'
		elseif self.AnchorPosition == 5 then
			anchor2 = '^'
			anchor4 = '<'
			anchor5 = '#'
			anchor6 = '>'
			anchor8 = 'v'
		elseif self.AnchorPosition == 6 then
			anchor3 = '^'
			anchor6 = '#'
			anchor5 = '<'
			anchor9 = 'v'
		elseif self.AnchorPosition == 7 then
			anchor4 = '^'
			anchor7 = '#'
			anchor8 = '>'
		elseif self.AnchorPosition == 8 then
			anchor5 = '^'
			anchor8 = '#'
			anchor7 = '<'
			anchor9 = '>'
		elseif self.AnchorPosition == 9 then
			anchor6 = '^'
			anchor9 = '#'
			anchor8 = '<'
		end

		if #self.HeightTextBox.TextInput.Value > 0 and Current.Artboard.Height > tonumber(self.HeightTextBox.TextInput.Value) then
			local r = function(str)
				if string.find(str, "%^") then
					str = str:gsub('%^','v')
				elseif string.find(str, "v") then
					str = str:gsub('v','%^')
				end
				return str
			end
			anchor1 = r(anchor1)
			anchor2 = r(anchor2)
			anchor3 = r(anchor3)
			anchor4 = r(anchor4)
			anchor5 = r(anchor5)
			anchor6 = r(anchor6)
			anchor7 = r(anchor7)
			anchor8 = r(anchor8)
			anchor9 = r(anchor9)
		end

		if #self.WidthTextBox.TextInput.Value > 0 and Current.Artboard.Width > tonumber(self.WidthTextBox.TextInput.Value) then
			local r = function(str)
				if string.find(str, ">") then
					str = str:gsub('>','<')
				elseif string.find(str, "<") then
					str = str:gsub('<','>')
				end
				return str
			end
			anchor1 = r(anchor1)
			anchor2 = r(anchor2)
			anchor3 = r(anchor3)
			anchor4 = r(anchor4)
			anchor5 = r(anchor5)
			anchor6 = r(anchor6)
			anchor7 = r(anchor7)
			anchor8 = r(anchor8)
			anchor9 = r(anchor9)
		end

		self.Anchor1.Text = anchor1
		self.Anchor2.Text = anchor2
		self.Anchor3.Text = anchor3
		self.Anchor4.Text = anchor4
		self.Anchor5.Text = anchor5
		self.Anchor6.Text = anchor6
		self.Anchor7.Text = anchor7
		self.Anchor8.Text = anchor8
		self.Anchor9.Text = anchor9
	end,

	Show = function(self)
		Current.Window = self
		return self
	end,

	Close = function(self)
		Current.Input = nil
		Current.Window = nil
		self = nil
	end,

	Flash = function(self)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
		sleep(0.15)
		self.Visible = false
		Draw()
		sleep(0.15)
		self.Visible = true
		Draw()
	end,

	ButtonClick = function(self, button, x, y)
		if button.X <= x and button.Y <= y and button.X + button.Width > x and button.Y + button.Height > y then
			button:Click()
		end
	end,

	Click = function(self, side, x, y)
		local items = {self.OkButton, self.WidthTextBox, self.HeightTextBox, self.Anchor1, self.Anchor2, self.Anchor3, self.Anchor4, self.Anchor5, self.Anchor6, self.Anchor7, self.Anchor8, self.Anchor9}
		for i, v in ipairs(items) do
			if CheckClick(v, x, y) then
				v:Click(side, x, y)
			end
		end
		return true
	end
}

----------------------

function CheckOpenArtboard()
	if Current.Artboard then
		return true
	else
		return false
	end
end

function CheckSelectedLayer()
	if Current.Artboard and Current.Layer then
		return true
	else
		return false
	end
end

function DisplayNewDocumentWindow()
	NewDocumentWindow:Initialise(function(self, success, path, width, height, format, backgroundColour)
		if success then
			if path:sub(-4) ~= format then
				path = path .. format
			end
			local oldWindow = self
			Current.Input = nil
			Current.Window = nil
			makeDocument = function()oldWindow:Close()NewDocument(path, width, height, format, backgroundColour)end
			local _fs = fs
			if OneOS then
				_fs = OneOS.FS
			end
			if _fs.exists(path) then
				ButtonDialougeWindow:Initialise('File Exists', path..' already exists! Use a different name and try again.', 'Ok', nil, function(window, ok)
					window:Close()
					oldWindow:Show()
				end):Show()
			elseif format == '.nfp' then
				Current.Window = nil
				ButtonDialougeWindow:Initialise('Use NFP?', 'The NFT format does not support text or layers, if you use it you will only be able to use 1 layer and not have any text.', 'Use NFP', 'Cancel', function(window, ok)
					window:Close()
					if ok then
						makeDocument()
					else
						oldWindow:Show()
					end
				end):Show()
			elseif format == '.nft' then
				ButtonDialougeWindow:Initialise('Use NFT?', 'The NFT format does not support layers, if you use it you will only be able to use 1 layer.', 'Use NFT', 'Cancel', function(window, ok)
					window:Close()
					if ok then
						makeDocument()
					else
						oldWindow:Show()
					end
				end):Show()
			else
				makeDocument()
			end

			
		else
			self:Close()
		end
	end):Show()
end

function NewDocument(path, width, height, format, backgroundColour)
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	ab = Artboard:New(_fs.getName(path), path, width, height, format, backgroundColour)
	Current.Tool = Tools[2]
	Current.Toolbar:Update()
	Current.Modified = false
	Draw()
end

function DisplayToolSizeWindow()
	if not CheckOpenArtboard() then
		return
	end	
	TextDialougeWindow:Initialise('Change Tool Size', 'Enter the new tool size you\'d like to use.', 'Ok', 'Cancel', function(window, success, value)
		if success then
			Current.ToolSize = math.ceil(tonumber(value))
			if Current.ToolSize < 1 then
				Current.ToolSize = 1
			elseif Current.ToolSize > 50 then
				Current.ToolSize = 50
			end
			ModuleNamed('Tools'):Update()
		end
		window:Close()
	end, true):Show()	
end

--[[
	Attempt to figure out what format the image is if it doesn't have an extension
]]--
function GetFormat(path)
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	local file = _fs.open(path, 'r')
	local content = file.readAll()
	file.close()
	if type(textutils.unserialize(content)) == 'table' then
		-- It's a serlized table, asume sketch
		return '.skch'
	elseif string.find(content, string.char(30)) or string.find(content, string.char(31)) then
		-- Contains the characters that set colours, asume nft
		return '.nft'
	else
		-- Otherwise asume nfp
		return '.nfp'
	end
end

function DisplayOpenDocumentWindow()
	OpenDocumentWindow:Initialise(function(self, success, path)
		self:Close()
		if success then
			OpenDocument(path)
		end
	end):Show()
end


local function Extension(path, addDot)
	if not path then
		return nil
	elseif not string.find(fs.getName(path), '%.') then
		if not addDot then
			return fs.getName(path)
		else
			return ''
		end
	else
		local _path = path
		if path:sub(#path) == '/' then
			_path = path:sub(1,#path-1)
		end
		local extension = _path:gmatch('\.[0-9a-z]+$')()
		if extension then
			extension = extension:sub(2)
		else
			--extension = nil
			return ''
		end
		if addDot then
			extension = '.'..extension
		end
		return extension:lower()
	end
end

local RemoveExtension = function(path)
	if path:sub(1,1) == '.' then
		return path
	end
	local extension = Extension(path)
	if extension == path then
		return fs.getName(path)
	end
	return string.gsub(path, extension, ''):sub(1, -2)
end
--[[
	Open a documet at a given path
]]--
function OpenDocument(path)
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	if _fs.exists(path) and not _fs.isDir(path) then
		local format = Extension(path, true)
		if (not format or format == '') and (format ~= '.nfp' and format ~= '.nft' and format ~= '.skch') then
			format = GetFormat(path)
		end
		local layers = {}
		if format == '.nfp' then
			layers = ReadNFP(path)
		elseif format == '.nft' then
			layers = ReadNFT(path)		
		elseif format == '.skch' then
			layers = ReadSKCH(path)
		end

		for i, layer in ipairs(layers) do
			if layer.Visible == nil then
				layer.Visible = true
			end
			if layer.Index == nil then
				layer.Index = 1
			end
			if layer.Name == nil then
				if layer.Index == 1 then
					layer.Name = 'Background'
				else
					layer.Name = 'Layer'
				end
			end
			if layer.BackgroundColour == nil then
				layer.BackgroundColour = colours.white
			end
		end

		if not layers[1] then
			--log('File could not be read.')
			return
		end

		local width = #layers[1].Pixels
		local height = #layers[1].Pixels[1]

		Current.Artboard = nil
		local _fs = fs
		if OneOS then
			_fs = OneOS.FS
		end
		ab = Artboard:New(_fs.getName('Image'), path, width, height, format, nil, layers)
		Current.Tool = Tools[2]
		Current.Toolbar:Update()
		Current.Modified = false
		Draw()
	end
end

function MakeNewLayer()
	if not CheckOpenArtboard() then
		return
	end
	if Current.Artboard.Format == '.skch' then
		TextDialougeWindow:Initialise('New Layer Name', 'Enter the name you want for the next layer.', 'Ok', 'Cancel', function(window, success, value)
			if success then
				Current.Artboard:MakeLayer(value, colours.transparent)
			end
			window:Close()
		end):Show()	
	else
		local format = 'NFP'
		if Current.Artboard.Format == '.nft' then
			format = 'NFT'
		end
		ButtonDialougeWindow:Initialise(format..' does not support layers!', 'The format you are using, '..format..', does not support multiple layers. Use SKCH to have more than one layer.', 'Ok', nil, function(window)
			window:Close()
		end):Show()
	end
end

function ResizeDocument()
	if not CheckOpenArtboard() then
		return
	end
	ResizeDocumentWindow:Initialise(function(window, width, height, anchor)
		window:Close()
		local topResize = 0
		local rightResize = 0
		local bottomResize = 0
		local leftResize = 0

		if anchor == 1 then
			rightResize = 1
			bottomResize = 1
		elseif anchor == 2 then
			rightResize = 0.5
			leftResize = 0.5
			bottomResize = 1
		elseif anchor == 3 then
			leftResize = 1
			bottomResize = 1
		elseif anchor == 4 then
			rightResize = 1
			bottomResize = 0.5
			topResize = 0.5
		elseif anchor == 5 then
			rightResize = 0.5
			leftResize = 0.5
			bottomResize = 0.5
			topResize = 0.5
		elseif anchor == 6 then
			leftResize = 1
			bottomResize = 0.5
			topResize = 0.5
		elseif anchor == 7 then
			rightResize = 1
			topResize = 1
		elseif anchor == 8 then
			rightResize = 0.5
			leftResize = 0.5
			topResize = 1
		elseif anchor == 9 then
			leftResize = 1
			topResize = 1
		end

		topResize = topResize * (height - Current.Artboard.Height)
		if topResize > 0 then
			topResize = math.floor(topResize)
		else
			topResize = math.ceil(topResize)
		end

		bottomResize = bottomResize * (height - Current.Artboard.Height)
		if bottomResize > 0 then
			bottomResize = math.ceil(bottomResize)
		else
			bottomResize = math.floor(bottomResize)
		end

		leftResize = leftResize * (width - Current.Artboard.Width)
		if leftResize > 0 then
			leftResize = math.floor(leftResize)
		else
			leftResize = math.ceil(leftResize)
		end

		rightResize = rightResize * (width - Current.Artboard.Width)
		if rightResize > 0 then
			rightResize = math.ceil(rightResize)
		else
			rightResize = math.floor(rightResize)
		end

		Current.Artboard:Resize(topResize, bottomResize, leftResize, rightResize)
	end):Show()
end

function RenameLayer()
	if not CheckOpenArtboard() then
		return
	end
	if Current.Artboard.Format == '.skch' then
		TextDialougeWindow:Initialise("Rename Layer '"..Current.Layer.Name.."'", 'Enter the new name you want the layer to be called.', 'Ok', 'Cancel', function(window, success, value)
			if success then
				Current.Layer.Name = value
			end
			window:Close()
		end):Show()	
	else
		local format = 'NFP'
		if Current.Artboard.Format == '.nft' then
			format = 'NFT'
		end
		ButtonDialougeWindow:Initialise(format..' does not support layers!', 'The format you are using, '..format..', does not support renaming layers. Use SKCH to rename layers.', 'Ok', nil, function(window)
			window:Close()
		end):Show()
	end
end

function DeleteLayer()
	if not CheckOpenArtboard() then
		return
	end
	if Current.Artboard.Format == '.skch' then
		if #Current.Artboard.Layers > 1 then
			ButtonDialougeWindow:Initialise("Delete Layer '"..Current.Layer.Name.."'?", 'Are you sure you want delete the layer?', 'Ok', 'Cancel', function(window, success)
				if success then
					Current.Layer:Remove()
				end
				window:Close()
			end):Show()
		else
			ButtonDialougeWindow:Initialise('Can not delete layer!', 'You can not delete the last layer of an image! Make another layer to delete this one.', 'Ok', nil, function(window)
				window:Close()
			end):Show()
		end
	else
		local format = 'NFP'
		if Current.Artboard.Format == '.nft' then
			format = 'NFT'
		end
		ButtonDialougeWindow:Initialise(format..' does not support layers!', 'The format you are using, '..format..', does not support deleting layers. Use SKCH to deleting layers.', 'Ok', nil, function(window)
			window:Close()
		end):Show()
	end
end

needsDraw = false
isDrawing = false
function Draw()
	if isDrawing then
		needsDraw = true
		return
	end
	needsDraw = false
	isDrawing = true
	if not Current.Window then
		Drawing.Clear(UIColours.Background)
	else
		Drawing.DrawArea(1, 2, Drawing.Screen.Width, Drawing.Screen.Height, '|', colours.black, colours.lightGrey)
	end

	if Current.Artboard then
		ab:Draw()
	end

	if Current.InterfaceVisible then
		Current.MenuBar:Draw()
		Current.Toolbar.Width = Current.Toolbar.ExpandedWidth
		Current.Toolbar:Draw()
	else
		Current.Toolbar.Width = Current.Toolbar.ExpandedWidth
	end

	if Current.InterfaceVisible and Current.Menu then
		Current.Menu:Draw()
	end

	if Current.Window then
		Current.Window:Draw()
	end

	if not Current.InterfaceVisible then
		ShowInterfaceButton:Draw()
	end

	Drawing.DrawBuffer()
	if Current.Input and not Current.Menu then
		term.setCursorPos(Current.CursorPos[1], Current.CursorPos[2])
		term.setCursorBlink(true)
		term.setTextColour(Current.CursorColour)
	else
		term.setCursorBlink(false)
	end

	if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
		Current.SelectionDrawTimer = os.startTimer(0.5)
	end
	isDrawing = false
	if needsDraw then
		Draw()
	end
end

function LoadMenuBar()
	Current.MenuBar = MenuBar:Initialise({
		Button:Initialise(1, 1, nil, nil, colours.grey, Current.MenuBar, function(self, side, x, y, toggle)
			if toggle then
				Menu:New(1, 2, {
					{
						Title = "New...",
						Click = function()
							DisplayNewDocumentWindow()
						end,
						Keys = {
							keys.leftCtrl,
							keys.n
						}
					},
					{
						Title = 'Open...',
						Click = function()
							DisplayOpenDocumentWindow()
						end,
						Keys = {
							keys.leftCtrl,
							keys.o
						}
					},
					{
						Separator = true
					},
					{
						Title = 'Save...',
						Click = function()
							Current.Artboard:Save()
						end,
						Keys = {
							keys.leftCtrl,
							keys.s
						},
						Enabled = function()
							return CheckOpenArtboard()
						end
					},
					{
						Separator = true
					},
					{
						Title = 'Quit',
						Click = function()
							if Close() then
								OneOS.Close()
							end
						end
					},
			--[[
					{
						Title = 'Save As...',
						Click = function()

						end
					}	
			]]--
				}, self, true)
			else
				Current.Menu = nil
			end
			return true 
		end, 'File', colours.lightGrey, false),
		Button:Initialise(7, 1, nil, nil, colours.grey, Current.MenuBar, function(self, side, x, y, toggle)
			if not self.Toggle then
				Menu:New(7, 2, {
			--[[
					{
						Title = "Undo",
						Click = function()
						end,
						Keys = {
							keys.leftCtrl,
							keys.z
						},
						Enabled = function()
							return false
						end
					},
					{
						Title = 'Redo',
						Click = function()
							
						end,
						Keys = {
							keys.leftCtrl,
							keys.y
						},
						Enabled = function()
							return false
						end
					},
					{
						Separator = true
					},
			]]--
					{
						Title = 'Cut',
						Click = function()
							Clipboard.Cut(Current.Layer:PixelsInSelection(true), 'sketchpixels')
						end,
						Keys = {
							keys.leftCtrl,
							keys.x
						},
						Enabled = function()
							return Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil
						end
					},
					{
						Title = 'Copy',
						Click = function()
							Clipboard.Copy(Current.Layer:PixelsInSelection(), 'sketchpixels')
						end,
						Keys = {
							keys.leftCtrl,
							keys.c
						},
						Enabled = function()
							return Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil
						end
					},
					{
						Title = 'Paste',
						Click = function()
							Current.Layer:InsertPixels(Clipboard.Paste())
						end,
						Keys = {
							keys.leftCtrl,
							keys.v
						},
						Enabled = function()
							return (not Clipboard.isEmpty()) and Clipboard.Type == 'sketchpixels'
						end
					}
				}, self, true)
			else
				Current.Menu = nil
			end
			return true 
		end, 'Edit', colours.lightGrey, false),
		Button:Initialise(13, 1, nil, nil, colours.grey, Current.MenuBar, function(self, side, x, y, toggle)
			if toggle then
				Menu:New(13, 2, {
					{
						Title = "Resize...",
						Click = function()
							ResizeDocument()
						end,
						Keys = {
							keys.leftCtrl,
							keys.r
						},
						Enabled = function()
							return CheckOpenArtboard()
						end
					},
					{
						Title = "Crop",
						Click = function()
							local top = 0
							local left = 0
							local bottom = 0
							local right = 0
							if Current.Selection[1].x < Current.Selection[2].x then
								left = Current.Selection[1].x - 1
								right = Current.Artboard.Width - Current.Selection[2].x
							else
								left = Current.Selection[2].x - 1
								right = Current.Artboard.Width - Current.Selection[1].x
							end
							if Current.Selection[1].y < Current.Selection[2].y then
								top = Current.Selection[1].y - 1
								bottom = Current.Artboard.Height - Current.Selection[2].y
							else
								top = Current.Selection[2].y - 1
								bottom = Current.Artboard.Height - Current.Selection[1].y
							end
							Current.Artboard:Resize(-1*top, -1*bottom, -1*left, -1*right)

							Current.Selection[2] = nil
						end,
						Enabled = function()
							if CheckSelectedLayer() and Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
								return true
							else
								return false
							end
						end
					},
					{
						Separator = true
					},
					{
						Title = 'New Layer...',
						Click = function()
							MakeNewLayer()
						end,
						Keys = {
							keys.leftCtrl,
							keys.l
						},
						Enabled = function()
							return CheckOpenArtboard()
						end
					},
					{
						Title = 'Delete Layer',
						Click = function()
							DeleteLayer()
						end,
						Enabled = function()
							return CheckSelectedLayer()
						end
					},
					{
						Title = 'Rename Layer...',
						Click = function()
							RenameLayer()
						end,
						Enabled = function()
							return CheckSelectedLayer()
						end
					},
					{
						Separator = true
					},
					{
						Title = 'Erase Selection',
						Click = function()
							Current.Layer:EraseSelection()
						end,
						Keys = {
							keys.delete
						},
						Enabled = function()
							if CheckSelectedLayer() and Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then
								return true
							else
								return false
							end
						end
					},
					{
						Separator = true
					},
					{
						Title = 'Hide Interface',
						Click = function()
							Current.InterfaceVisible = not Current.InterfaceVisible
						end,
						Keys = {
							keys.tab
						}
					}
				}, self, true)
			else
				Current.Menu = nil
			end
			return true 
		end, 'Image', colours.lightGrey, false),
		
		Button:Initialise(20, 1, nil, nil, colours.grey, Current.MenuBar, function(self, side, x, y, toggle)
			if toggle then
				local menuItems = {{
						Title = "Change Size",
						Click = function()
							DisplayToolSizeWindow()
						end,
						Keys = {
							keys.leftCtrl,
							keys.t
						}
					},
					{
						Separator = true
					}
				}
				
				local _keys = {'h','p','e','f','s','m','t'}
				for i, tool in ipairs(Tools) do
					table.insert(menuItems, {
						Title = tool.Name,
						Click = function()
							SetTool(tool)
							local m = ModuleNamed('Tools')
							m:Update(m.ToolbarItem)
						end,
						Keys = {
							keys[_keys[i]]
						},
						Enabled = function()
							return CheckOpenArtboard()
						end
					})
				end

				Menu:New(20, 2, menuItems, self, true)
			else
				Current.Menu = nil
			end
			return true 
		end, 'Tools', colours.lightGrey, false),
	})
end

function Timer(event, timer)
	if timer == Current.ControlPressedTimer then
		Current.ControlPressedTimer = nil
	elseif timer == Current.SelectionDrawTimer then
		if Current.Artboard then
			Current.Artboard.SelectionIsBlack = not Current.Artboard.SelectionIsBlack
			Draw()
		end
	end
end

function Initialise(arg)
	if not OneOS then
		SplashScreen()
	end
	EventRegister('mouse_click', TryClick)
	EventRegister('mouse_drag', function(event, side, x, y)TryClick(event, side, x, y, true)end)
	EventRegister('mouse_scroll', Scroll)
	EventRegister('key', HandleKey)
	EventRegister('char', HandleKey)
	EventRegister('timer', Timer)
	EventRegister('terminate', function(event) if Close() then error( "Terminated", 0 ) end end)


	Current.Toolbar = Toolbar:New('right', true)

	for k, v in pairs(Modules) do
		v:Initialise()
	end
	
	--term.setBackgroundColour(UIColours.Background)
	--term.clear()

	LoadMenuBar()

	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	if arg and _fs.exists(arg) then
		OpenDocument(arg)
	else
		DisplayNewDocumentWindow()
		Current.Window.Visible = false
	end

	ShowInterfaceButton = Button:Initialise(Drawing.Screen.Width - 15, 1, nil, 1, colours.grey, nil, function(self)
		Current.InterfaceVisible = true
		Draw()
	end, 'Show Interface')

	Draw()
	if Current.Window then
		Current.Window.Visible = true
		Draw()
	end

	EventHandler()
end

function SplashScreen()
	local splashIcon = {{1,1,1,256,256,256,256,256,256,256,256,1,1,1,},{1,256,256,8,8,8,8,8,8,8,8,256,256,1,},{256,8,8,8,8,8,8,8,8,8,8,8,8,256,},{256,256,256,8,8,8,8,8,8,8,8,256,256,256,},{256,256,256,256,256,256,256,256,256,256,256,256,256,256,},{2048,2048,256,256,256,256,256,256,256,256,256,256,2048,2048,},{2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,},{2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,},{2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,},{2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,},{256,256,2048,2048,2048,2048,2048,2048,2048,2048,2048,2048,256,256,},{1,256,256,256,256,256,256,256,256,256,256,256,256,1,},{1,1,1,256,256,256,256,256,256,256,256,1,1,1,},["text"]={{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," ","S","k","e","t","c","h"," "," "," "," ",},{" "," "," "," "," "," ","b","y"," "," "," "," "," "," ",},{" "," "," "," "," ","o","e","e","d"," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},{" "," "," "," "," "," "," "," "," "," "," "," "," "," ",},},["textcol"]={{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,256,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,1,1,1,1,1,1,32768,32768,32768,32768,},{32768,32768,32768,32768,8,8,8,8,8,8,8,32768,32768,32768,},{32768,32768,32768,32768,1,1,1,1,1,32768,8,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},{32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,},},}
	Drawing.Clear(colours.white)
	Drawing.DrawImage((Drawing.Screen.Width - 14)/2, (Drawing.Screen.Height - 13)/2, splashIcon, 14, 13)
	Drawing.DrawBuffer()
	parallel.waitForAny(function()sleep(1)end, function()os.pullEvent('mouse_click')end)
end

LongestString = function(input, key)
	local length = 0
	for i = 1, #input do
		local value = input[i]
		if key then
			if value[key] then
				value = value[key]
			else
				value = ''
			end
		end
		local titleLength = string.len(value)
		if titleLength > length then
			length = titleLength
		end
	end
	return length
end

function HandleKey(...)
	local args = {...}
	local event = args[1]
	local keychar = args[2]
	if event == 'key' and Current.Tool and Current.Tool.Name == 'Text' and Current.Input and (keychar == keys.up or keychar == keys.down or keychar == keys.left or keychar == keys.right) then
		local currentPos = {Current.CursorPos[1] - Current.Artboard.X + 1, Current.CursorPos[2] - Current.Artboard.Y + 1}
		if keychar == keys.up then
			currentPos[2] = currentPos[2] - 1
		elseif keychar == keys.down then
			currentPos[2] = currentPos[2] + 1
		elseif keychar == keys.left then
			currentPos[1] = currentPos[1] - 1
		elseif keychar == keys.right then
			currentPos[1] = currentPos[1] + 1
		end

		if currentPos[1] < 1 then
			currentPos[1] = 1
		end

		if currentPos[1] > Current.Artboard.Width then
			currentPos[1] = Current.Artboard.Width
		end

		if currentPos[2] < 1 then
			currentPos[2] = 1
		end

		if currentPos[2] > Current.Artboard.Height then
			currentPos[2] = Current.Artboard.Height
		end

		Current.Tool:Use(currentPos[1], currentPos[2])
		Current.Modified = true
		Draw()
	elseif Current.Input then
		if event == 'char' then
			Current.Input:Char(keychar)
		elseif event == 'key' then
			Current.Input:Key(keychar)
		end
	elseif event == 'key' then
		CheckKeyboardShortcut(keychar)
	end
end

function Scroll(event, direction, x, y)
	if Current.Window and Current.Window.OpenButton then
		Current.Window.Scroll = Current.Window.Scroll + direction
		if Current.Window.Scroll < 0 then
			Current.Window.Scroll = 0
		elseif Current.Window.Scroll > Current.Window.MaxScroll then
			Current.Window.Scroll = Current.Window.MaxScroll
		end
	end
	Draw()
end

function CheckKeyboardShortcut(key)
	local shortcuts = {}

	if key == keys.leftCtrl then
		Current.ControlPressedTimer = os.startTimer(0.5)
		return
	end
	if Current.ControlPressedTimer then
		shortcuts[keys.n] = function() DisplayNewDocumentWindow() end
		shortcuts[keys.o] = function() DisplayOpenDocumentWindow() end
		shortcuts[keys.s] = function() Current.Artboard:Save() end
		shortcuts[keys.x] = function() if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then Clipboard.Cut(Current.Layer:PixelsInSelection(true), 'sketchpixels') end end
		shortcuts[keys.c] = function() if Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then Clipboard.Copy(Current.Layer:PixelsInSelection(), 'sketchpixels') end end
		shortcuts[keys.v] = function() if (not Clipboard.isEmpty()) and Clipboard.Type == 'sketchpixels' then Current.Layer:InsertPixels(Clipboard.Paste()) end end
		shortcuts[keys.r] = function() ResizeDocument() end
		shortcuts[keys.l] = function() MakeNewLayer() end
	end

	shortcuts[keys.delete] = function() if CheckSelectedLayer() and Current.Selection and Current.Selection[1] and Current.Selection[2] ~= nil then Current.Layer:EraseSelection() Draw() end end
	shortcuts[keys.backspace] = shortcuts[keys.delete]
	shortcuts[keys.tab] = function() Current.InterfaceVisible = not Current.InterfaceVisible Draw() end

	shortcuts[keys.h] = function() SetTool(ToolNamed('Hand')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.e] = function() SetTool(ToolNamed('Eraser')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.p] = function() SetTool(ToolNamed('Pencil')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.f] = function() SetTool(ToolNamed('Fill Bucket')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.m] = function() SetTool(ToolNamed('Move')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.s] = function() SetTool(ToolNamed('Select')) ModuleNamed('Tools'):Update() Draw() end
	shortcuts[keys.t] = function() SetTool(ToolNamed('Text')) ModuleNamed('Tools'):Update() Draw() end

	if shortcuts[key] then
		shortcuts[key]()
		return true
	else
		return false
	end
end

--[[
	Check if the given object falls under the click coordinates
]]--
function CheckClick(object, x, y)
	if object.X <= x and object.Y <= y and object.X + object.Width > x and object.Y + object.Height > y then
		return true
	end
end

--[[
	Attempt to clicka given object
]]--
function DoClick(object, side, x, y, drag)
	if object and CheckClick(object, x, y) then
		return object:Click(side, x - object.X + 1, y - object.Y + 1, drag)
	end	
end

--[[
	Try to click at the given coordinates
]]--
function TryClick(event, side, x, y, drag)
	if Current.InterfaceVisible and Current.Menu then
		if DoClick(Current.Menu, side, x, y, drag) then
			Draw()
			return
		else
			if Current.Menu.Owner and Current.Menu.Owner.Toggle then
				Current.Menu.Owner.Toggle = false
			end
			Current.Menu = nil
			Draw()
			return
		end
	elseif Current.Window then
		if DoClick(Current.Window, side, x, y, drag) then
			Draw()
			return
		else
			Current.Window:Flash()
			return
		end
	end
	local interfaceElements = {}

	if Current.InterfaceVisible then
		table.insert(interfaceElements, Current.MenuBar)
	else
		table.insert(interfaceElements, ShowInterfaceButton)
	end

	for i, v in ipairs(Lists.Interface.Toolbars) do
		for i, v2 in ipairs(v.ToolbarItems) do
			table.insert(interfaceElements, v2)
		end
		table.insert(interfaceElements, v)
	end

	table.insert(interfaceElements, Current.Artboard)

	for i, object in ipairs(interfaceElements) do
		if DoClick(object, side, x, y, drag) then
			Draw()
			return
		end		
	end
	Draw()
end

--[[
	Registers functions to run on certain events
]]--
function EventRegister(event, func)
	if not Events[event] then
		Events[event] = {}
	end

	table.insert(Events[event], func)
end

--[[
	The main loop event handler, runs registered event functinos
]]--
function EventHandler()
	while true do
		local event, arg1, arg2, arg3, arg4 = os.pullEventRaw()
		if Events[event] then
			for i, e in ipairs(Events[event]) do
				e(event, arg1, arg2, arg3, arg4)
			end
		end
	end
end

--[[
	Thanks to NitrogenFingers for the colour functions and NFT + NFP read/write functions
]]--

--[[
	Gets the hex value from a colour
]]--
local hexnums = { [10] = "a", [11] = "b", [12] = "c", [13] = "d", [14] = "e" , [15] = "f" }
local function getHexOf(colour)
    if colour == colours.transparent or not colour or not tonumber(colour) then
            return " "
    end
    local value = math.log(colour)/math.log(2)
    if value > 9 then
            value = hexnums[value]
    end
    return value
end

--[[
	Gets the colour from a hex value
]]--
local function getColourOf(hex)
	if hex == ' ' then
		return colours.transparent
	end
    local value = tonumber(hex, 16)
    if not value then return nil end
    value = math.pow(2,value)
    return value
end

--[[
	Saves the current artboard in .skch format
]]--
function SaveSKCH()
	local layers = {}
	for i, l in ipairs(Current.Artboard.Layers) do
		local pixels = SaveNFT(i)
		local layer = {
			Name = l.Name,
			Pixels = pixels,
			BackgroundColour = l.BackgroundColour,
			Visible = l.Visible,
			Index = l.Index,
		}
		table.insert(layers, layer)
	end
	return layers
end

--[[
	Saves the current artboard in .nft format
]]--
function SaveNFT(layer)
	layer = layer or 1
	local lines = {}
	local width = Current.Artboard.Width
	local height = Current.Artboard.Height
	for y = 1, height do
		local line = ''
		local currentBackgroundColour = nil
		local currentTextColour = nil
		for x = 1, width do
			local pixel = Current.Artboard.Layers[layer].Pixels[x][y]
			if pixel.BackgroundColour ~= currentBackgroundColour then
				line = line..string.char(30)..getHexOf(pixel.BackgroundColour)
				currentBackgroundColour = pixel.BackgroundColour
			end
			if pixel.TextColour ~= currentTextColour then
				line = line..string.char(31)..getHexOf(pixel.TextColour)
				currentTextColour = pixel.TextColour
			end
			line = line .. pixel.Character
		end
		table.insert(lines, line)
	end
	return lines
end

--[[
	Saves the current artboard in .nfp format
]]--
function SaveNFP()
	local lines = {}
	local width = Current.Artboard.Width
	local height = Current.Artboard.Height
	for y = 1, height do
		local line = ''
		for x = 1, width do
			line = line .. getHexOf(Current.Artboard.Layers[1].Pixels[x][y].BackgroundColour)
		end
		table.insert(lines, line)
	end
	return lines
end

--[[
	Reads a .nfp file from the given path
]]--
function ReadNFP(path)
	local pixels = {}
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	local file = _fs.open(path, 'r')
	local line = file.readLine()
	local y = 1
	while line do
		for x = 1, #line do
			if not pixels[x] then
				pixels[x] = {}
			end
			pixels[x][y] = {BackgroundColour = getColourOf(line:sub(x,x))}
		end
		y = y + 1
		line = file.readLine()
	end
	file.close()
	return {{Pixels = pixels}}
end

--[[
	Reads a .nft file from the given path
]]--
function ReadNFT(path)
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	local file = _fs.open(path, 'r')
	local line = file.readLine()
	local lines = {}
	while line do
		table.insert(lines, line)
		line = file.readLine()
	end
	file.close()
	return {{Pixels = ParseNFT(lines)}}
end

--[[
	Converts the lines of an .nft document to readble pixel data
]]--
function ParseNFT(lines)
	local pixels = {}
	for y, line in ipairs(lines) do
		local bgNext, fgNext = false, false
		local currBG, currFG = nil,nil
		local writePosition = 1
		for x = 1, #line do
			if not pixels[writePosition] then
				pixels[writePosition] = {}
			end

			local nextChar = string.sub(line, x, x)
            if nextChar:byte() == 30 then
                    bgNext = true
            elseif nextChar:byte() == 31 then
                    fgNext = true
            elseif bgNext then
                    currBG = getColourOf(nextChar)
                    if currBG == nil then
                    	currBG = colours.transparent
                    end
                    bgNext = false
            elseif fgNext then
                    currFG = getColourOf(nextChar)
                    fgNext = false
            else
                    if nextChar ~= " " and currFG == nil then
                            currFG = colours.white
                    end
                    pixels[writePosition][y] = {BackgroundColour = currBG, TextColour = currFG, Character = nextChar}
                    writePosition = writePosition + 1
            end
		end
	end
	return pixels
end

--[[
	Read a .skch file from the given path
]]--
function ReadSKCH(path)
	local _fs = fs
	if OneOS then
		_fs = OneOS.FS
	end
	local file = _fs.open(path, 'r')
	local _layers = textutils.unserialize(file.readAll())
	file.close()
	local layers = {}

	for i, l in ipairs(_layers) do
		local layer = {
			Name = l.Name,
			Pixels = ParseNFT(l.Pixels),
			BackgroundColour = l.BackgroundColour,
			Visible = l.Visible,
			Index = l.Index,
		}
		table.insert(layers, layer)
	end
	return layers
end

--[[
	Start the program after all functions and tables are loaded
]]--
if term.isColor and term.isColor() then
	Initialise(...)
else
	print('Sorry, but Sketch only works on Advanced (gold) Computers')
end