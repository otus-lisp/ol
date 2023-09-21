#pragma once
#ifdef _WIN32

#define lstat stat

int pipe(int pipes[2]);

int pipe(int pipes[2])
{
	static int id = 0;
	char name[64];
	snprintf(name, sizeof(name), "\\\\.\\pipe\\ol%d", ++id); //todo: __sync_fetch_and_add(&id, 1));

	HANDLE pipe1 = CreateNamedPipe(name,
			PIPE_ACCESS_DUPLEX|WRITE_DAC,
			PIPE_TYPE_BYTE|PIPE_READMODE_BYTE|PIPE_NOWAIT,
			2, 1024, 1024, 2000, NULL);

	HANDLE pipe2 = CreateFile(name,
			GENERIC_WRITE, 0,
			NULL,
			OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
			NULL);

	// https://stackoverflow.com/questions/7369445/is-there-a-windows-equivalent-to-fdopen-for-handles
	pipes[0] = _open_osfhandle((intptr_t)pipe1, _O_APPEND | _O_RDONLY);
	pipes[1] = _open_osfhandle((intptr_t)pipe2, _O_APPEND | _O_WRONLY);

	// not required: ConnectNamedPipe(pipe1, NULL);
	return 0;
}

// read workaround:
static
ssize_t readEx(int fd, void *buf, size_t size)
{
	int got;
#ifdef _WIN64
	int chunk_size = size;
#else
	int chunk_size = 24 * 1024;
#endif

	// regular reading
	if (!_isatty(fd) || _kbhit()) { // we don't get hit by kb in pipe
		got = read(fd, (char *) buf, min(chunk_size, size));
	} else {
		errno = EAGAIN;
		return -1;
	}

	if (got == -1) {
		switch (errno) {
#if HAVE_SOCKETS
		case EBADF: // have we tried to read from socket?
			got = recv(fd, (char *) buf, size, 0);
			if (got < 0 && WSAGetLastError() == WSAEWOULDBLOCK)
				errno = EAGAIN;
			break;
#endif

		// https://lists.gnu.org/archive/html/bug-gnulib/2011-04/msg00170.html
		// The other failure of the non-blocking I/O on pipes test on mingw is because
		// when read() is called on a non-blocking pipe fd with an empty buffer, it
		// fails with EINVAL. Whereas POSIX says that it should fail with EAGAIN.
		case EINVAL: {
			HANDLE handle = (HANDLE)_get_osfhandle(fd);
			// pipe?
			if (GetFileType(handle) == FILE_TYPE_PIPE) {
				DWORD state;
				// pipe in non-blocking mode?
				if (GetNamedPipeHandleState (handle, &state, NULL, NULL, NULL, NULL, 0)
						  && (state & PIPE_NOWAIT) != 0) {
					errno = EAGAIN;
				}
			}
			break; }
		}
	}
	return got;
}
#define read readEx

// write workaround:
static
ssize_t writeEx(int fd, void *buf, size_t size)
{
	int wrote;

	// regular writing (files and pipes)
	wrote = write(fd, buf, size);

#if HAVE_SOCKETS
	// sockets workaround
	if (wrote == -1 && errno == EBADF) {
		wrote = send(fd, buf, size, 0);
	}
#endif

	return wrote;
}
#define write writeEx

int fsync(int fd)
{
	HANDLE h = (HANDLE) _get_osfhandle(fd);

	if (h == INVALID_HANDLE_VALUE) {
		errno = EBADF;
		return -1;
	}
	if (!FlushFileBuffers(h)) {
		switch (GetLastError()) {
			case ERROR_ACCESS_DENIED:
				return 0;
			case ERROR_INVALID_HANDLE: // fsync a tty?
				errno = EINVAL;
				break;
			default:
				errno = EIO;
		}
		return -1;
	}
	return 0;
}

// --------------------------------------------------------
// -=( fork )=---------------------------------------------
// sample implementation can be found at
// https://github.com/jonclayden/multicore/blob/master/src/forknt.c
// originally from: "Windows NT/2000 native API reference" ISBN 1-57870-199-6.

// TBD.

#endif
