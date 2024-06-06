from setuptools import setup, find_packages

setup(
    name="freecheck",
    version="0.4.0",
    description="A free check printing utility.",
    url="https://github.com/JoshRodd/freecheck",
    classifiers=[],
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    package_data={"postscript": ["postscript/*.ps"]},
    include_package_data=True,
    py_modules=[],
    python_requires=">=3.12.3",
)
