"""Sphinx configuration shared by local builds and the published docs."""

project = "Godot Apple Plugins"
root_doc = "index"
language = "en"
exclude_patterns = [".DS_Store"]
extensions = ["sphinx.ext.intersphinx", "sphinx_tabs.tabs"]
intersphinx_mapping = {"godot": ("https://docs.godotengine.org/en/stable/", None)}

# Keep the original docs theme explicit instead of using Sphinx's default.
html_theme = "classic"
html_title = project
html_short_title = project
html_theme_options = {"sidebarwidth": "260px"}
html_sidebars = {"**": ["searchbox.html", "localtoc.html", "relations.html"]}
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_baseurl = "https://xibbon.github.io/GodotApplePlugins/"

html_show_copyright = False
html_show_sphinx = False
