from setuptools import setup, find_packages

setup(
    name="catalogador",
    version="0.0.1",
    # Exclude top-level tests and any tests that might accidentally be placed
    # inside the package directory (catalogador/tests). This prevents the
    # import-file-mismatch pytest errors caused by duplicated test module names.
    packages=find_packages(
        exclude=("tests", "tests.*", "catalogador.tests", "catalogador.tests.*")
    ),
    include_package_data=True,
    description="Catalogador EsSalud backend package (minimal setup.py to enable editable install)",
    install_requires=[
        "fastapi==0.121.0",
        "uvicorn==0.38.0",
        "starlette==0.49.3",
        "pydantic==2.12.4",
        "pydantic-core==2.41.5",
        "portalocker==2.7.0",
        "requests==2.32.5",
        "pdfplumber==0.11.7",
        "pdfminer.six==20250506",
        "python-multipart==0.0.20",
        "openai==2.7.1",
    ],
)
