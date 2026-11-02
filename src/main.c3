module l3;

import libc;
import std::io;
import std::io::file;
import std::io::path;
import std::core::string;
import std::time::datetime;

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

		// Print first folders
		foreach (item: pathList)
		{
			String fullpath = string::format(mem, "%s/%s", pathname, item);
			defer free(fullpath);
			if (path::is_dir((Path)fullpath))
			{
				printPathItem(item, pathname, width);
			}
		}

		// Print files
		foreach (item: pathList)
		{
			String fullpath = string::format(mem, "%s/%s", pathname, item);
			defer free(fullpath);
			if (path::is_file((Path)fullpath))
			{
				printPathItem(item, pathname, width);
			}
		}
	}
	return 0;
}

fn void printTableHeader(int win_width)
{
	io::printf("\x1b[1;90m");
	io::printf("   "); // 3 spaces

	// Size column
	io::printf("%-*s", 12, "Size");
	// Modified column
	io::printf("%-*s", 15, "Modified");
	// Name column
	io::printf(" %-*s", win_width - 32, "Name");

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

		// Print size and datetime
		if (try size)
		{
			io::printf(" %-*d", 12, size);
			Time modifiedTime = file::last_modified(relativePath)!!;
			DateTime dateTime = datetime::from_time(modifiedTime).to_local();
			io::printf("%.*d %.*s %.*d:%.*d", 2, dateTime.day, 3, dateTime.month, 2, dateTime.hour, 2, dateTime.min);
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
			Time modifiedTime = dirModifiedAt((Path)relativePath);
			DateTime dateTime = datetime::from_time(modifiedTime).to_local();
			io::printf("%.*d %.*s %.*d:%.*d", 2, dateTime.day, 3, dateTime.month, 2, dateTime.hour, 2, dateTime.min);
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

fn Time dirModifiedAt(Path fullpath)
{
	Time md = time::now(); // Time for the lastest modified file in this folder
	Duration diff = (Duration)md; // Used to identify the latest modified file in this folder
	DateTime dt; // DateTime for the latest modified file in this folder
	PathList? pathlist = path::ls(mem, fullpath);
	defer (void)pathlist.free();

	if (catch excuse = pathlist)
	{
		io::printfn("Error: %s", excuse);
	}

	if (try pathlist)
	{
		foreach(item: pathlist)
		{
			String newpath = string::format(mem, "%s/%s", fullpath, item);
			defer free(newpath);

			if (path::is_file((Path)newpath))
			{
				Time lastMod = file::last_modified(newpath)!!;
				if (md - lastMod < diff)
				{
					diff = md - lastMod;
					md = lastMod;
				}
			}

			if (path::is_dir((Path)newpath))
			{
				Time lastMod = dirModifiedAt((Path)newpath);
				if (md - lastMod < diff)
				{
					diff = md - lastMod;
					md = lastMod;
				}
			}
		}

		// Here we can calculate the DateTime
	}

	return md;
}
