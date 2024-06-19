from setuptools import setup, Extension
from Cython.Build import cythonize
import numpy

ext_modules = [
    Extension(name="mib_prop",
              sources=["mib_prop.pyx",
                       "src/read_mq1_headers.c",
                       "src/mq1_single.c",
                       "src/mq1_quad.c",
                       "src/mib_utils.c",
                       ],
              include_dirs=[numpy.get_include(), "src/"],
              define_macros=[('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION')],
              ),
]

setup(
    name="mib_prop",
    ext_modules=cythonize(ext_modules, annotate=True),
)
