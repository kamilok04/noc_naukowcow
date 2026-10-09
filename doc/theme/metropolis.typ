// This theme is inspired by https://github.com/matze/mtheme
// The origin code was written by https://github.com/Enivex

#import "@preview/touying:0.8.0": *

// Exact image geometry from the reference PowerPoint deck.
// Positions are relative to the full 16:9 page, matching the PPTX slide
// coordinate system (including objects that extend beyond the slide edge).
#let img-at(path, x, y, width, height) = {
  place(top + left, dx: x, dy: y)[
    #image(path, width: width, height: height, fit: "stretch")
  ]
}

#let common-footer = {
  img-at("img/image3.png", 2.799803%, 87.990595%, 17.694808%, 9.790799%)
  img-at("img/image2.png", 22.796047%, 87.990595%, 17.694808%, 9.790784%)
  img-at("img/image4.png", 42.211622%, 82.135637%, 21.269841%, 21.269845%)
  img-at("img/image5.svg", 66.010171%, 89.725241%, 29.941658%, 6.632969%)
}

#let title-image-layer = {
  img-at("img/image1.png", 0%, -4.617600%, 100%, 100%)
  place(top + left, dx: 0%, dy: 83.694080%)[#box(fill: white, width: 100%, height: 16.305920%)]
  common-footer
  img-at("img/image6.svg", 79.951001%, 0.834777%, 11.247302%, 19.932327%)
  img-at("img/image7.svg", 6.560441%, -1.173214%, 14.656668%, 18.126115%)
}

#let regular-image-layer = {
  img-at("img/image8.png", 0%, 0%, 100%, 100%)
  common-footer
  img-at("img/image6.svg", 87.550607%, 1.448002%, 8.401222%, 14.888539%)
  img-at("img/image9.png", 47.548450%, 2.015413%, 7.380069%, 16.876276%)
  img-at("img/image10.png", 56.020595%, 4.570531%, 4.675115%, 11.766010%)
}

#let section-image-layer = {
  img-at("img/image11.png", 0%, 0%, 100%, 100%)
  common-footer
  img-at("img/image6.svg", 83.298163%, 6.527355%, 8.401222%, 14.888539%)
  img-at("img/image9.png", 64.918578%, 7.094765%, 7.380069%, 16.876276%)
  img-at("img/image10.png", 73.390723%, 9.649883%, 4.675115%, 11.766010%)
}



/// Default slide function for the presentation.
///
/// - title (string): The title of the slide. Default is `auto`.
///
/// - config (dictionary): The configuration of the slide. You can use `config-xxx` to set the configuration of the slide. For several configurations, you can use `utils.merge-dicts` to merge them.
///
/// - repeat (int, string): The number of subslides. Default is `auto`, which means touying will automatically calculate the number of subslides.
///
///   The `repeat` argument is necessary when you use `#slide(repeat: 3, self => [ .. ])` style code to create a slide. The callback-style `uncover` and `only` cannot be detected by touying automatically.
///
/// - setting (function): The setting of the slide. You can use it to add some set/show rules for the slide.
///
/// - composer (function, array): The composer of the slide. You can use it to set the layout of the slide.
///
///   For example, `#slide(composer: (1fr, 2fr, 1fr))[A][B][C]` to split the slide into three parts. The first and the last parts will take 1/4 of the slide, and the second part will take 1/2 of the slide.
///
///   If you pass a non-function value like `(1fr, 2fr, 1fr)`, it will be assumed to be the first argument of the `cols` function.
///
///   The `cols` function is a simple wrapper of the `grid` function. It means you can use the `grid.cell(colspan: 2, ..)` to make the cell take 2 columns.
///
///   For example, `#slide(composer: 2)[A][B][#grid.cell(colspan: 2)[Footer]]` will make the `Footer` cell take 2 columns.
///
///   If you want to customize the composer, you can pass a function to the `composer` argument. The function should receive the contents of the slide and return the content of the slide, like `#slide(composer: grid.with(columns: 2))[A][B]`.
///
/// - bodies (array): The contents of the slide. You can call the `slide` function with syntax like `#slide[A][B][C]` to create a slide.
#let slide(
  title: auto,
  align: auto,
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  if align != auto {
    self.store.align = align
  }
  let header(self) = {
    set std.align(top)
    show: components.cell.with(inset: 1em)
    set std.align(bottom + center)
    set text(fill: self.colors.neutral-dark, weight: "medium", size: 1.2em)
    {
      v(1em)
      grid(columns: (4fr, 1fr, 2fr, 1fr), [], [], text(self.colors.secondary.lighten(75%), 0.765em, self.info.title))
      v(1fr)
      grid(columns: (1fr, 2fr), [], if title != auto {
        utils.fit-to-width(grow: false, 100%, title)
      } else {
        utils.call-or-display(self, self.store.header)
      })
    }
  }

  let self = utils.merge-dicts(
    self,
    config-page(
      fill: self.colors.neutral-lightest,
      background: regular-image-layer,
      header: header,
      footer: none,
    ),
  )
  let new-setting = body => {
    show: std.align.with(self.store.align)
    set text(fill: self.colors.neutral-darkest)
    show: setting
    body
  }
  touying-slide(
    self: self,
    config: config,
    repeat: repeat,
    setting: new-setting,
    composer: composer,
    ..bodies,
  )
})


/// Title slide for the presentation. You should update the information in the `config-info` function. You can also pass the information directly to the `title-slide` function.
///
/// Example:
///
/// ```typst
/// #show: metropolis-theme.with(
///   config-info(
///     title: [Title],
///     logo: emoji.city,
///   ),
/// )
///
/// #title-slide(subtitle: [Subtitle], extra: [Extra information])
/// ```
///
/// - config (dictionary): The configuration of the slide. You can use `config-xxx` to set the configuration of the slide. For several configurations, you can use `utils.merge-dicts` to merge them.
///
/// - extra (string, none): The extra information you want to display on the title slide.
#let title-slide(
  config: (:),
  extra: none,
  ..args,
) = touying-slide-wrapper(self => {
  let header = none

  self = utils.merge-dicts(
    self,
    config-common(freeze-slide-counter: true),
    config-page(
      fill: self.colors.neutral-lightest,
      background: title-image-layer,
      header: header,
      footer: none,
      margin: (top: 62.5%, bottom: 12.5%, x: 12.5%),
    ),
    config,
  )
  let info = self.info + args.named()

  let body = {
    set text(fill: white)
    set std.align(center)
    block(
      width: 100%,
      inset: (top: 1.25em),
      {
        text(weight: "medium", info.title)
        set text(size: .8em)
        linebreak()
        info.subtitle
        linebreak()
        info.author
      },
    )
  }
  touying-slide(self: self, body)
})


/// New section slide for the presentation. You can update it by updating the `new-section-slide-fn` argument for `config-common` function.
///
/// Example: `config-common(new-section-slide-fn: new-section-slide.with(numbered: false))`
///
/// - config (dictionary): The configuration of the slide. You can use `config-xxx` to set the configuration of the slide. For several configurations, you can use `utils.merge-dicts` to merge them.
///
/// - level (int): The level of the heading.
///
/// - numbered (boolean): Indicates whether the heading is numbered.
///
/// - body (auto): The body of the section. It will be passed by touying automatically.
#let new-section-slide(
  config: (:),
  level: 1,
  numbered: true,
  body,
) = touying-slide-wrapper(self => {
  let setting(level, numbered, body) = {
    set std.align(horizon)
    show: pad.with(20%)
    set text(size: 1.5em)
    stack(
      dir: ttb,
      spacing: 1em,
      text(self.colors.neutral-darkest, utils.display-current-heading(
        level: level,
        numbered: numbered,
        style: auto,
      )),
      block(
        height: 2pt,
        width: 100%,
        spacing: 0pt,
        components.progress-bar(
          height: 2pt,
          self.colors.primary,
          self.colors.primary-light,
        ),
      ),
    )
    text(self.colors.neutral-dark, body)
  }
  self = utils.merge-dicts(
    self,
    config-page(
      fill: self.colors.neutral-lightest,
      background: section-image-layer,
      footer: none,
    ),
  )
  touying-slide(
    self: self,
    config: config,
    setting: setting.with(level, numbered),
    body,
  )
})


/// Focus on some content.
///
/// Example: `#focus-slide[Wake up!]`
///
/// - config (dictionary): The configuration of the slide. You can use `config-xxx` to set the configuration of the slide. For several configurations, you can use `utils.merge-dicts` to merge them.
///
/// - align (alignment): The alignment of the content. Default is `horizon + center`.
#let focus-slide(
  config: (:),
  align: horizon + center,
  body,
) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(
    self,
    config,
    config-common(freeze-slide-counter: true),
    // 3em: was 2em scaled by the focus text's own `set text(size: 1.5em)`.
    config-page(
      fill: self.colors.neutral-lightest,
      background: title-image-layer,
      footer: none,
      margin: (top: 60%, bottom: 12.5%, x: 12.5%),
    ),
  )
  touying-slide(
    self: self,
    config: config,
    setting: it => std.align(
      align,
      text(fill: self.colors.neutral-lightest, size: 1.5em, it),
    ),
    body,
  )
})
/// Speaker-note panel for this theme. Only styling; `touying-notes` does the layout.
#let notes(self: none, ..args) = touying-notes(
  self: self,
  header: self => pad(x: 32pt, y: 16pt, text(
    fill: self.colors.neutral-lightest,
    utils.display-current-heading(depth: self.slide-level),
  )),
  header-fill: self.colors.secondary,
  fill: self.colors.neutral-lightest,
  ..args,
)




/// Touying metropolis theme.
///
/// Example:
///
/// ```typst
/// #show: metropolis-theme.with(aspect-ratio: "16-9", config-colors(primary: blue))
/// ```
///
/// Consider using:
///
/// ```typst
/// #set text(font: "Fira Sans", weight: "light", size: 20pt)
/// #show math.equation: set text(font: "Fira Math")
/// #set strong(delta: 100)
/// #set par(justify: true)
/// ```
///
/// The default colors:
///
/// ```typ
/// config-colors(
///   primary: rgb("#eb811b"),
///   primary-light: rgb("#d6c6b7"),
///   secondary: rgb("#23373b"),
///   neutral-lightest: rgb("#fafafa"),
///   neutral-dark: rgb("#23373b"),
///   neutral-darkest: rgb("#23373b"),
/// )
/// ```
///
/// - aspect-ratio (string): The aspect ratio of the slides. Default is `16-9`.
///
/// - align (alignment): The alignment of the content. Default is `horizon`.
///
/// - header (content, function): The header of the slide. Default is `self => utils.display-current-heading(setting: utils.fit-to-width.with(grow: false, 100%), depth: self.slide-level)`.
///
/// - header-right (content, function): The right part of the header. Default is `self => self.info.logo`.
///
/// - footer (content, function): The footer of the slide. Default is `none`.
///
/// - footer-right (content, function): The right part of the footer. Default is `context utils.slide-counter.display() + " / " + utils.last-slide-number`.
///
/// - footer-progress (boolean): Whether to show the progress bar in the footer. Default is `true`.
#let metropolis-theme(
  aspect-ratio: "16-9",
  align: horizon,
  header: self => utils.display-current-heading(
    setting: utils.fit-to-width.with(grow: false, 100%),
    depth: self.slide-level,
  ),
  header-right: self => self.info.logo,
  footer: none,
  footer-right: context utils.slide-counter.display() + " / " + utils.last-slide-number,
  footer-progress: true,
  ..args,
  body,
) = {
  set text(size: 15pt)

  show: touying-slides.with(
    config-page(
      ..utils.page-args-from-aspect-ratio(aspect-ratio),
      header-ascent: 0%,
      footer-descent: 0%,
      margin: (top: 32%, bottom: 12.5%, x: 2em),
    ),
    config-common(
      slide-fn: slide,
      notes-fn: notes,
      new-section-slide-fn: new-section-slide,
    ),
    config-methods(
      alert: utils.alert-with-primary-color,
    ),
    config-colors(
      primary: rgb("#f19da9"),
      primary-light: rgb("#f19da9").lighten(75%),
      secondary: rgb("#000"),
      neutral-lightest: rgb("#ffffff"),
      neutral-dark: rgb("#000"),
      neutral-darkest: rgb("#000"),
    ),
    // save the variables for later use
    config-store(
      align: align,
      header: header,
      header-right: header-right,
      footer: footer,
      footer-right: footer-right,
      footer-progress: footer-progress,
    ),
    ..args,
  )

  body
}
