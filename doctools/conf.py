"""Sphinx configuration shared by local builds and the published docs."""

project = "Godot Apple Plugins"
root_doc = "index"
language = "en"
exclude_patterns = [".DS_Store"]
extensions = ["sphinx.ext.intersphinx", "sphinx_tabs.tabs"]
intersphinx_mapping = {"godot": ("https://docs.godotengine.org/en/stable/", None)}

# The custom layout uses Sphinx's content and search with a DocC-style shell.
html_theme = "basic"
templates_path = ["_templates"]
html_title = project
html_short_title = project
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_js_files = ["navigation.js"]
html_baseurl = "https://xibbon.github.io/GodotApplePlugins/"

html_show_copyright = False
html_show_sphinx = False
