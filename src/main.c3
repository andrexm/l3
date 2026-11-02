module l3;

import libc;
import std::io;
import std::io::file;
import std::io::path;

const int STDOUT_FILENO = 1;
const ulong TIOCGWINSZ = 0x5413;

// Window size struct
struct WinSize {
	ushort ws_row;
	ushort ws_col;
	ushort ws_xpixel;
	ushort ws_ypixel;
}

fn int main(String[] args)
{
	WinSize ws;
	int width = 80; // fallback default
	String pathname = ".";

	if (libc::ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0)
	{
		width = (int)ws.ws_col;
	}

	if (args.len > 1)
	{
		pathname = args[1];
	}

	// Selected path
	Path? path = path::new(mem, pathname);
	if (catch excuse = path)
	{
		io::printfn("Excuse: %s", excuse);
	}
	defer (void)free(path);

	// Try to read path 
	PathList? pathList = path::ls(mem, path);
	if (catch excuse = pathList)
	{
		io::printfn("Excuse: %s", excuse);
	}
	defer (void)pathList.free();

	if (try pathList)
	{
		printTableHeader(width);
		foreach (item: pathList)
		{
			printPathItem(item, pathname, width);
		}
	}
	return 0;
}

fn void printTableHeader(int win_width)
{
	io::printf("\x1b[1;90m");
	io::printf("   "); // 3 spaces

	// Size column
	io::printf("%-*s", 15, "Size");
	// Name column
	io::printf("%-*s", win_width - 20, "Name");

	// Reset foreground
	io::printfn("\x1b[0m");
}

fn void printPathItem(Path path, String pathname, int width)
{
	String relativePath = pathname.concat(mem, "/");
			relativePath = relativePath.concat(mem, path);
	defer free(relativePath);

	if (file::is_file(relativePath))
	{
		// Get size
		long? size = file::get_size(relativePath);
		if (catch excuse = size)
		{
			io::printfn("Excuse: %s", excuse);
		}

		io::print("\x1b[92m"); // Yellow foreground
		io::print(" 🗎");

		// Print size
		if (try size)
		{
			io::printf(" %-*d", 12, size);
		}

		// Print name
		io::printfn(" -- %.*s", width - 20, path);
		io::print("\x1b[0m"); // Reset foreground
		return;
	}

	if (file::is_dir(relativePath))
	{
		io::print("\x1b[94m"); // Yellow foreground
		io::print(" 🗀 ");

		// Get size
		ulong? size = dirSize((Path)relativePath);
		if (catch excuse = size)
		{
			io::printfn("Excuse: %s", excuse);
		}

		// Print size
		if (try size)
		{
			io::printf("%-*d", 12, size);	
		}

		// Print name
		io::printf(" -- %.*s", width - 20, path);
		io::printn("\x1b[0m"); // Reset foreground
		return;
	}

	io::printfn("? %s", path);
}

fn ulong? dirSize(Path fullpath)
{
	ulong? size;
	PathList? list = path::ls(mem, fullpath);
	defer (void)list.free();

	if (catch excuse = list)
	{
		io::printfn("Error: %s", excuse);
	}

	if (try list)
	{
		foreach(item: list)
		{
			String fullname = fullpath.concat(mem, "/");
				fullname = fullname.concat(mem, item);
			defer free(fullname);

			if (path::is_file((Path)fullname))
			{
				size += (ulong)path::file_size((Path)fullname);
			}

			if (path::is_dir((Path)fullname))
			{
				size += dirSize((Path)fullname);
			}
		}
	}

	return size;
}
