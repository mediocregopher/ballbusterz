ballbusterz.love:
	zip -r ballbusterz.love *

clean:
	rm -f ballbusterz.love
	rm -rf releases/*

run: ballbusterz.love
	love-hg ballbusterz.love

release:
	love-release -lmw
