{
  lib,
  buildPythonPackage,
  fetchPypi,
  numpy,
  pandas,
  six,
  astropy,
  oldest-supported-numpy,
  pytestCheckHook,
  pytest-doctestplus,
  pythonOlder,
  setuptools-scm,
  wheel,
}:

buildPythonPackage rec {
  pname = "drms";
  version = "0.8.0";
  format = "pyproject";
  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-LgHu7mTgiL3n2lVaOhppdWfQiM0CFkK+6z6eBkLxmKY=";
  };

  nativeBuildInputs = [
    numpy
    oldest-supported-numpy
    setuptools-scm
    wheel
  ];

  propagatedBuildInputs = [
    numpy
    pandas
    six
  ];

  nativeCheckInputs = [
    astropy
    pytestCheckHook
    pytest-doctestplus
  ];

  disabledTests = [ "test_query_hexadecimal_strings" ];

  disabledTestPaths = [ "docs/tutorial.rst" ];

  pythonImportsCheck = [ "drms" ];

  meta = with lib; {
    description = "Access HMI, AIA and MDI data with Python";
    homepage = "https://github.com/sunpy/drms";
    license = licenses.bsd2;
    maintainers = [ ];
  };
}
