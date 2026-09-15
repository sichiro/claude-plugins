check:
	python3 scripts/check-plugin.py
	env -u MAKELEVEL sh plugins/harness/test.sh
