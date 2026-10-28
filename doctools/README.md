# Building the documentation

The Sphinx configuration, theme, styles, and Python dependencies live here so
the published site can be reproduced without a machine-specific configuration.

Create a virtual environment and install the dependencies from the repository root:

```sh
python3 -m venv /tmp/godotappleplugins-docs-venv
/tmp/godotappleplugins-docs-venv/bin/python -m pip install -r doctools/requirements.txt
```

Build the checked-in XML reference and Markdown guides using a current Godot
source checkout (needed for built-in class definitions and generator utilities):

```sh
PATH="/tmp/godotappleplugins-docs-venv/bin:$PATH" make -C doctools html \
  GODOT_DOCS_SOURCE=/path/to/godot/doc/classes \
  HTML_OUTPUT=/tmp/godotappleplugins-docs
```

The build resolves built-in class links through the official Godot documentation,
so a clean build needs network access. The DocC-style layout in `_templates/`
uses Sphinx's built-in base theme and code tabs. `_static/custom.css` provides
the responsive layout and light/dark appearance; `navigation.js` handles symbol
filtering and the mobile navigator. The output includes `.nojekyll` so GitHub Pages preserves
Sphinx's `_static` assets.

The root `make deploy-docs` target also regenerates XML using the local Godot
test project before publishing HTML to the `docs` branch's `/docs` directory.
