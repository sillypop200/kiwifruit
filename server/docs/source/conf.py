# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import sys
# Allow autodoc to import app.py from server/
sys.path.insert(0, os.path.abspath('../..'))

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'kiwifruit-server'
copyright = '2026, Anurag Krosuru, Savannah Brown, Zixiao Ma, Tingrui Zhang, Shawn Dong, Swesik Ramineni, Varun Talluri'
author = 'Anurag Krosuru, Savannah Brown, Zixiao Ma, Tingrui Zhang, Shawn Dong, Swesik Ramineni, Varun Talluri'
release = '0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',  # adds "View source" links
    'sphinx_markdown_builder',
]

templates_path = ['_templates']
exclude_patterns = []



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
