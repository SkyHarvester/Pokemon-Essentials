#===============================================================================
# Updated Pokedex UI for Pokémon Essentials v21.1
#===============================================================================
class PokemonPokedexInfo_Scene
  def pbStartScene(dexlist, index, region)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @dexlist = dexlist
    @index   = index
    @region  = region
    @page = 1
    @show_battled_count = false
    @typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Pokedex/icon_types"))
    @sprites = {}
    @sprites["background"] = ScrollingSprite.new(@viewport)
    @sprites["background"].setBitmap("Graphics/Pictures/Pokedex/bg_info")
    @sprites["background"].speed = 1
    @sprites["infoverlay"] = IconSprite.new(0, 0, @viewport)
    @sprites["infosprite"] = PokemonSprite.new(@viewport)
    @sprites["infosprite"].setOffset(PictureOrigin::CENTER)
    @sprites["infosprite"].x = 98
    @sprites["infosprite"].y = 112
    mappos = $game_map.metadata&.town_map_position
    if @region < 0
      @region = (mappos) ? mappos[0] : 0
    end
    @mapdata = GameData::TownMap.get(@region)
    @sprites["areamap"] = IconSprite.new(0, 0, @viewport)
    @sprites["areamap"].setBitmap("Graphics/Pictures/#{@mapdata.filename}")
    @sprites["areamap"].x += (Graphics.width - @sprites["areamap"].bitmap.width) / 2
    @sprites["areamap"].y += (Graphics.height + 32 - @sprites["areamap"].bitmap.height) / 2
    Settings::REGION_MAP_EXTRAS.each do |hidden|
      next if hidden[0] != @region || hidden[1] <= 0 || !$game_switches[hidden[1]]
      pbDrawImagePositions(
        @sprites["areamap"].bitmap,
        [["Graphics/Pictures/#{hidden[4]}",
          hidden[2] * PokemonRegionMap_Scene::SQUARE_WIDTH,
          hidden[3] * PokemonRegionMap_Scene::SQUARE_HEIGHT]]
      )
    end
    @sprites["areahighlight"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["areaoverlay"] = IconSprite.new(0, 0, @viewport)
    @sprites["areaoverlay"].setBitmap("Graphics/Pictures/Pokedex/overlay_area")
    @sprites["formfront"] = PokemonSprite.new(@viewport)
    @sprites["formfront"].setOffset(PictureOrigin::CENTER)
    @sprites["formfront"].x = 382
    @sprites["formfront"].y = 234
    @sprites["formback"] = PokemonSprite.new(@viewport)
    @sprites["formback"].setOffset(PictureOrigin::CENTER)
    @sprites["formback"].x = 124
    @sprites["formback"].y = 440
    @sprites["formicon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
    @sprites["formicon"].setOffset(PictureOrigin::CENTER)
    @sprites["formicon"].x = 64
    @sprites["formicon"].y = 100
    @sprites["uparrow"] = AnimatedSprite.new("Graphics/Pictures/uparrow", 8, 28, 40, 2, @viewport)
    @sprites["uparrow"].x = 242
    @sprites["uparrow"].y = 40
    @sprites["uparrow"].play
    @sprites["uparrow"].visible = false
    @sprites["downarrow"] = AnimatedSprite.new("Graphics/Pictures/downarrow", 8, 28, 40, 2, @viewport)
    @sprites["downarrow"].x = 242
    @sprites["downarrow"].y = 128
    @sprites["downarrow"].play
    @sprites["downarrow"].visible = false
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    pbUpdateDummyPokemon
    @available = pbGetAvailableForms
    drawPage(@page)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  # For standalone access, shows first page only.
  def pbStartSceneBrief(species)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    dexnum = 0
    dexnumshift = false
    if $player.pokedex.unlocked?(-1)   # National Dex is unlocked
      species_data = GameData::Species.try_get(species)
      if species_data
        nationalDexList = [:NONE]
        GameData::Species.each_species { |s| nationalDexList.push(s.species) }
        dexnum = nationalDexList.index(species_data.species) || 0
        dexnumshift = true if dexnum > 0 && Settings::DEXES_WITH_OFFSETS.include?(-1)
      end
    else
      ($player.pokedex.dexes_count - 1).times do |i|
        next if !$player.pokedex.unlocked?(i)
        num = pbGetRegionalNumber(i, species)
        next if num <= 0
        dexnum = num
        dexnumshift = true if Settings::DEXES_WITH_OFFSETS.include?(i)
        break
      end
    end
    @dexlist = [{
      :species => species,
      :name    => "",
      :height  => 0,
      :weight  => 0,
      :number  => dexnum,
      :shift   => dexnumshift
    }]
    @index = 0
    @page = 1
    @brief = true
    @typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Pokedex/icon_types"))
    @sprites = {}
    @sprites["background"] = ScrollingSprite.new(@viewport)
    @sprites["background"].setBitmap("Graphics/Pictures/Pokedex/bg_info")
    @sprites["background"].speed = 1
    @sprites["infoverlay"] = IconSprite.new(0, 0, @viewport)
    @sprites["infosprite"] = PokemonSprite.new(@viewport)
    @sprites["infosprite"].setOffset(PictureOrigin::CENTER)
    @sprites["infosprite"].x = 98
    @sprites["infosprite"].y = 136
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    pbUpdateDummyPokemon
    drawPage(@page)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @typebitmap.dispose
    @viewport.dispose
  end

  def pbUpdate
    if @page == 2
      intensity_time = System.uptime % 1.0   # 1 second per glow
      if intensity_time >= 0.5
        intensity = lerp(64, 256 + 64, 0.5, intensity_time - 0.5)
      else
        intensity = lerp(256 + 64, 64, 0.5, intensity_time)
      end
      @sprites["areahighlight"].opacity = intensity
    end
    pbUpdateSpriteHash(@sprites)
  end

  def pbUpdateDummyPokemon
    @species = @dexlist[@index][:species]
    @gender, @form, _shiny = $player.pokedex.last_form_seen(@species)
    @shiny = false
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    @sprites["infosprite"].setSpeciesBitmap(@species, @gender, @form, @shiny)
    @sprites["formfront"]&.setSpeciesBitmap(@species, @gender, @form, @shiny)
    if @sprites["formback"]
      @sprites["formback"].setSpeciesBitmap(@species, @gender, @form, @shiny, false, true)
      @sprites["formback"].y = 226
    end
    @sprites["formicon"]&.pbSetParams(@species, @gender, @form, @shiny)
  end

  def pbGetAvailableForms
    ret = []
    multiple_forms = false
    gender_differences = (GameData::Species.front_sprite_filename(@species, 0) == GameData::Species.front_sprite_filename(@species, 0, 1))
    # Find all genders/forms of @species that have been seen
    GameData::Species.each do |sp|
      next if sp.species != @species
      next if sp.form != 0 && (!sp.real_form_name || sp.real_form_name.empty?)
      next if sp.pokedex_form != sp.form
      multiple_forms = true if sp.form > 0
      if sp.single_gendered?
        real_gender = (sp.gender_ratio == :AlwaysFemale) ? 1 : 0
        next if !$player.pokedex.seen_form?(@species, real_gender, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
        real_gender = 2 if sp.gender_ratio == :Genderless
        ret.push([sp.form_name, real_gender, sp.form])
      elsif sp.form == 0 && !gender_differences
        2.times do |real_gndr|
          next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
          ret.push([sp.form_name || _INTL("One Form"), 0, sp.form])
          break
        end
      else
        2.times do |real_gndr|
          next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
          ret.push([sp.form_name, real_gndr, sp.form])
          break if sp.form_name && !sp.form_name.empty?
        end
      end
    end
    ret.sort! { |a, b| (a[2] == b[2]) ? a[1] <=> b[1] : a[2] <=> b[2] }
    ret.each do |entry|
      if entry[0]
        entry[0] = "" if !multiple_forms && !gender_differences
      else
        case entry[1]
        when 0 then entry[0] = _INTL("Male")
        when 1 then entry[0] = _INTL("Female")
        else
          entry[0] = (multiple_forms) ? _INTL("One Form") : _INTL("Genderless")
        end
      end
      entry[1] = 0 if entry[1] == 2
    end
    return ret
  end

  def drawPage(page)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @sprites["infosprite"].visible    = (@page == 1)
    @sprites["areamap"].visible       = (@page == 2) if @sprites["areamap"]
    @sprites["areahighlight"].visible = (@page == 2) if @sprites["areahighlight"]
    @sprites["areaoverlay"].visible   = (@page == 2) if @sprites["areaoverlay"]
    @sprites["formfront"].visible     = (@page == 3) if @sprites["formfront"]
    @sprites["formback"].visible      = (@page == 3) if @sprites["formback"]
    @sprites["formicon"].visible      = (@page == 3) if @sprites["formicon"]
    case page
    when 1 then drawPageInfo
    when 2 then drawPageArea
    when 3 then drawPageForms
    end
  end

  def drawPageInfo
    @sprites["background"].setBitmap(_INTL("Graphics/Pictures/Pokedex/bg_info"))
    @sprites["infoverlay"].setBitmap(_INTL("Graphics/Pictures/Pokedex/info_overlay"))
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(82, 82, 90)
    shadow = Color.new(165, 165, 173)
    imagepos = []
    if @brief
      @sprites["background"].setBitmap(_INTL("Graphics/Pictures/Pokedex/bg_capture"))
      @sprites["infoverlay"].setBitmap(_INTL("Graphics/Pictures/Pokedex/capture_overlay"))
      @sprites["capturebar"] = IconSprite.new(0, 0, @viewport)
      @sprites["capturebar"].setBitmap(_INTL("Graphics/Pictures/Pokedex/overlay_info"))
    end
    species_data = GameData::Species.get_species_form(@species, @form)
    indexText = "???"
    if @dexlist[@index][:number] > 0
      indexNumber = @dexlist[@index][:number]
      indexNumber -= 1 if @dexlist[@index][:shift]
      indexText = sprintf("%03d", indexNumber)
    end
    if @brief
      textpos = [
        # Text positioned 82 pixels from the left and 24 pixels from the top
        [_INTL("Pokémon Registration Complete"), 82, 24, 0, Color.new(255, 255, 255), Color.new(165, 165, 173)],
        # Text positioned 272 pixels from the left and 64 pixels from the top
        [_INTL("{1}{2} {3}", indexText, " ", species_data.name), 272, 64, 0, Color.new(82, 82, 90), Color.new(165, 165, 173)],
        # Text positioned 288 pixels from the left and 180 pixels from the top
        [_INTL("Height"), 288, 184, 0, base, shadow],
        # Text positioned 288 pixels from the left and 210 pixels from the top
        [_INTL("Weight"), 288, 214, 0, base, shadow]
      ]
    else
      textpos = [
        # Text positioned 272 pixels from the left and 24 pixels from the top
        [_INTL("{1}{2} {3}", indexText, " ", species_data.name), 272, 28, 0, Color.new(82, 82, 90), Color.new(165, 165, 173)],
        # Text positioned 288 pixels from the left and 140 pixels from the top
        [_INTL("Height"), 288, 140, 0, base, shadow],
        # Text positioned 288 pixels from the left and 170 pixels from the top
        [_INTL("Weight"), 288, 170, 0, base, shadow]
      ]
    end
    if $player.owned?(@species)
      if @brief
        textpos.push([_INTL("{1} Pokémon", species_data.category), 376, 100, 2, base, shadow])
      else
        textpos.push([_INTL("{1} Pokémon", species_data.category), 376, 60, 2, base, shadow])
      end
      height = species_data.height
      weight = species_data.weight
      if System.user_language[3..4] == "US"
        inches = (height / 0.254).round
        pounds = (weight / 0.45359).round
        if @brief
          textpos.push([_ISPRINTF("{1:d}'{2:02d}\"", inches / 12, inches % 12), 490, 180, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:4.1f} lbs.", pounds / 10.0), 490, 210, 1, base, shadow])
        else
          textpos.push([_ISPRINTF("{1:d}'{2:02d}\"", inches / 12, inches % 12), 490, 140, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:4.1f} lbs.", pounds / 10.0), 490, 170, 1, base, shadow])
        end
      else
        if @brief
          textpos.push([_ISPRINTF("{1:.1f} m", height / 10.0), 490, 180, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:.1f} kg", weight / 10.0), 490, 210, 1, base, shadow])
        else
          textpos.push([_ISPRINTF("{1:.1f} m", height / 10.0), 490, 140, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:.1f} kg", weight / 10.0), 490, 170, 1, base, shadow])
        end
      end
      base = Color.new(255, 255, 255)
      shadow = Color.new(165, 165, 173)
      if @brief
        drawTextEx(overlay, 38, 258, Graphics.width - (40 * 2), 4, species_data.pokedex_entry, base, shadow)
      else
        drawTextEx(overlay, 38, 220, Graphics.width - (40 * 2), 4, species_data.pokedex_entry, base, shadow)
      end
      footprintfile = GameData::Species.footprint_filename(@species, @form)
      if footprintfile
        footprint = RPG::Cache.load_bitmap("", footprintfile)
        if @brief
          overlay.blt(224, 150, footprint, footprint.rect)
        else
          overlay.blt(224, 110, footprint, footprint.rect)
        end
        footprint.dispose
      end
      if @brief
        imagepos.push(["Graphics/Pictures/Pokedex/icon_own", 210, 67])
      else
        imagepos.push(["Graphics/Pictures/Pokedex/icon_own", 210, 29])
      end
      species_data.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * 32, 102, 32)
        if @brief
          overlay.blt(296 + (100 * i), 130, @typebitmap.bitmap, type_rect)
        else
          overlay.blt(296 + (100 * i), 92, @typebitmap.bitmap, type_rect)
        end
      end
    else
      textpos.push([_INTL("????? Pokémon"), 274, 60, 0, base, shadow])
      if System.user_language[3..4] == "US"
        textpos.push([_INTL("???'??\""), 490, 138, 1, base, shadow])
        textpos.push([_INTL("????.? lbs."), 488, 170, 1, base, shadow])
      else
        textpos.push([_INTL("????.? m"), 488, 134, 1, base, shadow])
        textpos.push([_INTL("????.? kg"), 488, 170, 1, base, shadow])
      end
    end
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
  end

  def pbFindEncounter(enc_types, species)
    return false if !enc_types
    enc_types.each_value do |slots|
      next if !slots
      slots.each { |slot| return true if GameData::Species.get(slot[1]).species == species }
    end
    return false
  end

  def pbGetEncounterPoints
    visible_points = []
    @mapdata.point.each do |loc|
      next if loc[7] && !$game_switches[loc[7]]
      visible_points.push([loc[0], loc[1]])
    end
    town_map_width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    ret = []
    GameData::Encounter.each_of_version($PokemonGlobal.encounter_version) do |enc_data|
      next if !pbFindEncounter(enc_data.types, @species)
      map_metadata = GameData::MapMetadata.try_get(enc_data.map)
      next if !map_metadata || map_metadata.has_flag?("HideEncountersInPokedex")
      mappos = map_metadata.town_map_position
      next if mappos[0] != @region
      map_size = map_metadata.town_map_size
      map_width = 1
      map_height = 1
      map_shape = "1"
      if map_size && map_size[0] && map_size[0] > 0
        map_width = map_size[0]
        map_shape = map_size[1]
        map_height = (map_shape.length.to_f / map_width).ceil
      end
      map_width.times do |i|
        map_height.times do |j|
          next if map_shape[i + (j * map_width), 1].to_i == 0
          next if !visible_points.include?([mappos[1] + i, mappos[2] + j])
          ret[mappos[1] + i + ((mappos[2] + j) * town_map_width)] = true
        end
      end
    end
    return ret
  end

  def drawPageArea
    @sprites["background"].setBitmap(_INTL("Graphics/Pictures/Pokedex/bg_area"))
    @sprites["infoverlay"].setBitmap(_INTL("Graphics/Pictures/Pokedex/map_overlay"))
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    @sprites["areahighlight"].bitmap.clear
    points = pbGetEncounterPoints
    pointcolor   = Color.new(0, 248, 248)
    pointcolorhl = Color.new(192, 248, 248)
    town_map_width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    sqwidth = PokemonRegionMap_Scene::SQUARE_WIDTH
    sqheight = PokemonRegionMap_Scene::SQUARE_HEIGHT
    points.length.times do |j|
      next if !points[j]
      x = (j % town_map_width) * sqwidth
      x += (Graphics.width - @sprites["areamap"].bitmap.width) / 2
      y = (j / town_map_width) * sqheight
      y += (Graphics.height + 32 - @sprites["areamap"].bitmap.height) / 2
      @sprites["areahighlight"].bitmap.fill_rect(x, y, sqwidth, sqheight, pointcolor)
      if j - town_map_width < 0 || !points[j - town_map_width]
        @sprites["areahighlight"].bitmap.fill_rect(x, y - 2, sqwidth, 2, pointcolorhl)
      end
      if j + town_map_width >= points.length || !points[j + town_map_width]
        @sprites["areahighlight"].bitmap.fill_rect(x, y + sqheight, sqwidth, 2, pointcolorhl)
      end
      if j % town_map_width == 0 || !points[j - 1]
        @sprites["areahighlight"].bitmap.fill_rect(x - 2, y, 2, sqheight, pointcolorhl)
      end
      if (j + 1) % town_map_width == 0 || !points[j + 1]
        @sprites["areahighlight"].bitmap.fill_rect(x + sqwidth, y, 2, sqheight, pointcolorhl)
      end
    end
    base   = Color.new(255, 255, 255)
    shadow = Color.new(165, 165, 173)
    textpos = []
    if points.length == 0
      pbDrawImagePositions(overlay, [["Graphics/Pictures/Pokedex/overlay_areanone", 108, 188]])
      textpos.push([_INTL("Area unknown"), Graphics.width / 2, (Graphics.height / 2) + 6, :center, base, shadow])
    end
    textpos.push([@mapdata.name, 84, 10, :center, base, shadow])
    textpos.push([_INTL("{1}'s area", GameData::Species.get(@species).name), 380, 10, :center, base, shadow])
    pbDrawTextPositions(overlay, textpos)
  end

  def drawPageForms
    @sprites["background"].setBitmap(_INTL("Graphics/Pictures/Pokedex/bg_forms"))
    @sprites["infoverlay"].setBitmap(_INTL("Graphics/Pictures/Pokedex/forms_overlay"))
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(255, 255, 255)
    shadow = Color.new(165, 165, 173)
    formname = ""
    @available.each do |i|
      if i[1] == @gender && i[2] == @form
        formname = i[0]
        break
      end
    end
    textpos = [
      [_INTL("Forms"), 58, 10, 0, Color.new(255, 255, 255), Color.new(115, 115, 115)],
      [GameData::Species.get(@species).name, Graphics.width / 2, Graphics.height - 304, :center, base, shadow],
      [formname, Graphics.width / 2, Graphics.height - 280, :center, base, shadow]
    ]
    pbDrawTextPositions(overlay, textpos)
  end

  def pbGoToPrevious
    newindex = @index
    while newindex > 0
      newindex -= 1
      if $player.seen?(@dexlist[newindex][:species])
        @index = newindex
        break
      end
    end
  end

  def pbGoToNext
    newindex = @index
    while newindex < @dexlist.length - 1
      newindex += 1
      if $player.seen?(@dexlist[newindex][:species])
        @index = newindex
        break
      end
    end
  end

  def pbChooseForm
    index = 0
    @available.length.times do |i|
      if @available[i][1] == @gender && @available[i][2] == @form
        index = i
        break
      end
    end
    oldindex = -1
    loop do
      if oldindex != index
        $player.pokedex.set_last_form_seen(@species, @available[index][1], @available[index][2])
        pbUpdateDummyPokemon
        drawPage(@page)
        @sprites["uparrow"].visible   = (index > 0)
        @sprites["downarrow"].visible = (index < @available.length - 1)
        oldindex = index
      end
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::UP)
        pbPlayCursorSE
        index = (index + @available.length - 1) % @available.length
      elsif Input.trigger?(Input::DOWN)
        pbPlayCursorSE
        index = (index + 1) % @available.length
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        break
      end
    end
    @sprites["uparrow"].visible   = false
    @sprites["downarrow"].visible = false
  end

  def pbScene
    Pokemon.play_cry(@species, @form)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      if Input.trigger?(Input::ACTION)
        pbSEStop
        Pokemon.play_cry(@species, @form) if @page == 1
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        case @page
        when 1
          pbPlayDecisionSE
          @show_battled_count = !@show_battled_count
          dorefresh = true
        when 2
        when 3
          if @available.length > 1
            pbPlayDecisionSE
            pbChooseForm
            dorefresh = true
          end
        end
      elsif Input.trigger?(Input::UP)
        oldindex = @index
        pbGoToPrevious
        if @index != oldindex
          pbUpdateDummyPokemon
          @available = pbGetAvailableForms
          pbSEStop
          (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
          dorefresh = true
        end
      elsif Input.trigger?(Input::DOWN)
        oldindex = @index
        pbGoToNext
        if @index != oldindex
          pbUpdateDummyPokemon
          @available = pbGetAvailableForms
          pbSEStop
          (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
          dorefresh = true
        end
      elsif Input.trigger?(Input::LEFT)
        oldpage = @page
        @page -= 1
        @page = 1 if @page < 1
        @page = 3 if @page > 3
        if @page != oldpage
          pbPlayCursorSE
          dorefresh = true
        end
      elsif Input.trigger?(Input::RIGHT)
        oldpage = @page
        @page += 1
        @page = 1 if @page < 1
        @page = 3 if @page > 3
        if @page != oldpage
          pbPlayCursorSE
          dorefresh = true
        end
      end
      drawPage(@page) if dorefresh
    end
    return @index
  end

  def pbSceneBrief
    Pokemon.play_cry(@species, @form)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::ACTION)
        pbSEStop
        Pokemon.play_cry(@species, @form)
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        pbPlayCloseMenuSE
        break
      end
    end
  end
end

#===============================================================================
#
#===============================================================================
class PokemonPokedexInfoScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(dexlist, index, region)
    @scene.pbStartScene(dexlist, index, region)
    ret = @scene.pbScene
    @scene.pbEndScene
    return ret
  end

  def pbStartSceneSingle(species)
    region = -1
    if Settings::USE_CURRENT_REGION_DEX
      region = pbGetCurrentRegion
      region = -1 if region >= $player.pokedex.dexes_count - 1
    else
      region = $PokemonGlobal.pokedexDex
    end
    dexnum = pbGetRegionalNumber(region, species)
    dexnumshift = Settings::DEXES_WITH_OFFSETS.include?(region)
    dexlist = [{
      :species => species,
      :name    => GameData::Species.get(species).name,
      :height  => 0,
      :weight  => 0,
      :number  => dexnum,
      :shift   => dexnumshift
    }]
    @scene.pbStartScene(dexlist, 0, region)
    @scene.pbScene
    @scene.pbEndScene
  end

  def pbDexEntry(species)
    @scene.pbStartSceneBrief(species)
    @scene.pbSceneBrief
    @scene.pbEndScene
  end
end
