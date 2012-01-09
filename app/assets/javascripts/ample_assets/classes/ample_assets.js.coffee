class window.AmpleAssets

  constructor: (opts=undefined) ->
    @set_options(opts)
    @init()

  init: ->
    @options.onInit()
    @setup()
    @events()

  set_options: (opts) ->
    @current = 0
    ref = this
    default_options = 
      debug: false
      expanded: false
      id: "ample-assets"
      handle_text: 'Assets'
      expanded_height: 170
      collapsed_height: 25
      onInit: ->
        ref.log 'onInit()'
      onExpand: ->
        ref.log 'onExpand()'
      onCollapse: ->
        ref.log 'onCollapse()'
      panels_options:
        debug: false
        width: 950
        height: 100
        orientation: 'vertical'
        key_orientation: 'vertical'
        keyboard_nav: true
        auto: false
        parent: 'div'
        children: 'div.page'
      pages_options:
        interval: 5000
        width: 81 
        height: 81
        enabled: true
        distance: 10
        keyboard_nav: true
        auto: false
        orientation: 'horizontal'
        key_orientation: 'horizontal'
        per_page: 10
      pages: [
        { 
          id: 'recent-assets', 
          title: 'Recently Viewed',
          url: '/ample_assets/',
          panels: false
        }
      ]
    
    @loaded = false
    @options = default_options
    for k of opts
      @options[k] = opts[k]

  log: (msg) ->
    console.log "ample_assets.log: #{msg}" if @options.debug

  setup: ->
    id = @options.id
    layout = Mustache.to_html(@tpl('layout'),{ id: id, pages: @get_pages(), tabs: @get_pages('tab') })
    @handle = Mustache.to_html(@tpl('handle'),{ id: id, title: @options.handle_text })
    html = $(layout).prepend(@handle)
    $('body').append html
    @style()
    @drag_drop()
    @goto(0) if @options.expanded
    $('body').bind 'ample_uploadify.complete', =>
      @goto(0)
    
  style: ->
    @loading = $("##{@options.id}-tabs span.loading")
    $("##{@options.id} .container").css('height',200)
    if @options.expanded
      $("##{@options.id}").css({height:@options.expanded_height});

  goto: (i) ->
    @log "goto(#{i})"
    @current = i
    $("##{@options.id} .pages .page").hide()
    $("##{@options.id} .pages .page:nth-child(#{i+1})").show()
    @disable_panels()
    @activate(i)
    @load(i) unless @already_loaded(i)
    @enable_panel(i) if @already_loaded(i)

  drag_drop: ->
    $(".draggable").liveDraggable
      appendTo: "body"
      helper: "clone"

    $(".droppable").droppable
      activeClass: "notice"
      hoverClass: "success"
      drop: (event, ui) ->
        $(this).html ui.draggable.clone()
        asset_id = $(ui.draggable).attr("id").split("-")[1]
        $(this).parent().children().first().val asset_id
        $(this).parent().find('a.asset-remove').removeClass('hide').show()

  activate: (i) ->
    $("##{@options.id} a.tab").removeClass('on')
    $("##{@options.id} a.tab:nth-child(#{i+1})").addClass('on')

  next: ->
    if @current < @options.pages.length - 1
      @log "next()"
      @current += 1
      @goto(@current)

  previous: ->
    unless @current == 0
      @log "previous()"
      @current -= 1
      @goto(@current)

  get_pages: (tpl = 'page') ->
    ref = this
    html = ''
    $.each @options.pages, (idx,el) -> 
      html += Mustache.to_html ref.tpl(tpl), el
    html

  toggle: ->
    ref = this
    el = $("##{@options.id}")
    if @options.expanded 
      @options.expanded = false
      el.animate {height: @options.collapsed_height}, "fast", ->
        ref.collapse()
        ref.options.onCollapse()
    else
      @options.expanded = true
      el.animate {height: @options.expanded_height}, "fast", ->
        ref.expand()
        ref.options.onExpand()
        ref.goto(0)

  load: (i) ->
    ref = this
    if !@options.pages[i]['last_request_empty'] && @options.pages[i]['url']
      @loading.show()
      data_type = @options.pages[i]['data_type'] if @options.pages[i]['data_type']
      $.get @next_page_url(i), (response, xhr) ->
        ref.loading.hide()
        ref.options.pages[i]['loaded'] = true 
        if $.trim(response) == ''
          ref.options.pages[i]['last_request_empty'] = true
        else 
          switch data_type
            when "json"
              ref.load_json i, response
            when "html"
            else
              ref.load_html i, response
      , data_type
    else
      @log "ERROR --> Couldn't load page because there was no url" unless @options.pages[i]['last_request_empty']

  load_html: (i, response) ->
    @log "load(#{i}) html"
    selector = "##{@options.id} .pages .page:nth-child(#{(i+1)})" 
    selector += " ul" if @options.pages[i]['panels']
    $(selector).html(response)
    @panels(i)

  load_json: (i, response) ->
    @log "load(#{i}) json"
    panels_loaded = if @options.pages[i]['panel_selector'] then true else false
    ref = this
    selector = "##{@options.id} .pages .page:nth-child(#{(i+1)}) ul" 
    $.each response, (j,el) ->
      link = $('<a href="#"></a>').attr('id',"file-#{el.id}").addClass('draggable').click ->
      li = $('<li class="file"></li>').append(link).click (e) ->
        ref.modal_active = true
        $.facebox('<div class="asset-detail">some html</div>');
      
      if panels_loaded
        $(selector).amplePanels('append', li)
      else
        $(selector).append(li)
      ref.load_img(link, el.thumbnail)

    ref.panels(i) unless panels_loaded

  load_img: (el,src) ->
    img = new Image()
    $(img).load(->
      $(this).hide()
      $(el).html this
      $(this).fadeIn()
    ).attr src: src

  next_page_url: (i) ->
    @options.pages[i]['pages_loaded'] = 0 unless @options.pages[i]['pages_loaded']
    @options.pages[i]['pages_loaded'] += 1
    "#{@options.pages[i]['url']}?page=#{@options.pages[i]['pages_loaded']}"

  panels: (i) ->
    ref = this
    if @options.pages[i]['panels']
      @log "panels(#{i})"
      el = "##{@options.id} .pages .page:nth-child(#{(i+1)}) ul"
      @options.pages[i]['panel_selector'] = el
      @options.pages[i][''] = $(el).attr('id',"#{@options.pages[i]['id']}-panel")
      $(el).amplePanels(@options.pages_options)
        .bind 'slide_horizontal', (e,d,dir) ->
          ref.load(i) if dir == 'next'

  disable_panels: ->
    ref = this
    $.each @options.pages, (i,el) ->
      $(ref.options.pages[i]['panel_selector']).amplePanels('disable') if ref.options.pages[i]['panel_selector']

  enable_panel: (i) ->  
    $(@options.pages[i]['panel_selector']).amplePanels('enable') if @options.pages[i]['panel_selector']

  already_loaded: (i) ->
    typeof @options.pages[i]['loaded'] == 'boolean' && @options.pages[i]['loaded']

  remove: (el) ->
    parent = $(el).parent()
    parent.find('.droppable').empty().html('<span>Drag Asset Here</span>')
    parent.find('input').val('')
    $(el).hide()

  collapse: ->
    @disable_panels()

  expand: ->
    @goto(0)

  events: ->
    @modal_events()
    ref = this
    $("a.asset-remove").live 'click', ->
      ref.remove(this)
    $("##{@options.id}-handle").live 'click', ->
      ref.toggle()
    @key_down()
    tabs = $("##{@options.id} a.tab")
    $.each tabs, (idx, el) ->
      $(this).addClass('on') if idx == 0
      $(el).click ->
        ref.goto(idx)

  modal_events: ->
    @modal_active = false
    ref = this
    $(document).bind 'afterClose.facebox', ->
      ref.modal_active = false
    $(document).bind 'loading.facebox', ->
      ref.modal_active = true

  key_down: ->
    ref = this
    previous = 38
    next = 40
    escape = 27
    $(document).keydown (e) ->
      switch e.keyCode
        when previous
          ref.previous()
        when next
          ref.next()
        when escape
          ref.toggle() unless ref.modal_active

  tpl: (view) ->
    @tpls()[view]

  tpls: ->
    layout: '
    <div id="{{ id }}"><div class="background">
      <div class="container">
        <div id="{{ id }}-tabs" class="tabs">{{{ tabs }}}<span class="loading"></span></div>
        <div id="{{ id }}-pages" class="pages">{{{ pages }}}</div>
      </div></div>
    </div>'
    handle: '<a href="#" id="{{ id }}-handle" class="handle">{{ title }}</a>'
    tab: '<a href="#" data-role="{{ id }}" class="tab">{{ title }}</a>'
    page: '
    <div id="{{ id }}" class="page">
      <ul></ul>
    </div>'

jQuery.fn.liveDraggable = (opts) ->
  @live "mouseover", ->
    $(this).data("init", true).draggable opts  unless $(this).data("init")
