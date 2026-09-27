// SPDX-License-Identifier: 0BSD
#ifndef MALLOW_ARCHIVE_ABI_H
#define MALLOW_ARCHIVE_ABI_H
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>

// Minimal public libarchive 3 ABI declarations. macOS ships the library, but the tested SDK
// omits its headers. No library implementation is vendored or downloaded.
// Signatures checked against Apple's published archive.h and archive_entry.h:
// https://github.com/apple-oss-distributions/libarchive/tree/main/libarchive/libarchive
// Linux includes the system headers as an additional declaration/type compatibility check.
#if __has_include(<archive.h>) && __has_include(<archive_entry.h>)
#include <archive.h>
#include <archive_entry.h>
#else
struct archive;
struct archive_entry;
int archive_version_number(void);
struct archive *archive_read_new(void);
int archive_read_free(struct archive *);
int archive_read_support_filter_none(struct archive *);
int archive_read_support_filter_xz(struct archive *);
int archive_read_support_filter_gzip(struct archive *);
int archive_read_support_format_tar(struct archive *);
int archive_read_open_fd(struct archive *, int, size_t);
int archive_read_next_header(struct archive *, struct archive_entry **);
ssize_t archive_read_data(struct archive *, void *, size_t);
const char *archive_entry_pathname(struct archive_entry *);
const char *archive_entry_hardlink(struct archive_entry *);
const char *archive_entry_symlink(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
mode_t archive_entry_perm(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
struct archive *archive_write_new(void);
int archive_write_free(struct archive *);
int archive_write_set_format_pax_restricted(struct archive *);
int archive_write_open_filename(struct archive *, const char *);
int archive_write_header(struct archive *, struct archive_entry *);
ssize_t archive_write_data(struct archive *, const void *, size_t);
int archive_write_finish_entry(struct archive *);
int archive_write_close(struct archive *);
struct archive_entry *archive_entry_new(void);
void archive_entry_free(struct archive_entry *);
void archive_entry_set_pathname(struct archive_entry *, const char *);
void archive_entry_set_hardlink(struct archive_entry *, const char *);
void archive_entry_set_symlink(struct archive_entry *, const char *);
void archive_entry_set_filetype(struct archive_entry *, unsigned int);
void archive_entry_set_perm(struct archive_entry *, mode_t);
void archive_entry_set_size(struct archive_entry *, int64_t);
#define ARCHIVE_OK 0
#define ARCHIVE_EOF 1
#endif
static const unsigned int MALLOW_ARCHIVE_IFDIR = 0040000;
static const unsigned int MALLOW_ARCHIVE_IFREG = 0100000;
static const unsigned int MALLOW_ARCHIVE_IFLNK = 0120000;
#endif
