/*
 * wincent-icon-util_Version.h
 *
 * Copyright 2007-2010 Wincent Colaiuta.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#define WO_COPYRIGHT_YEARS      2007-2010
#define WO_INFO_PLIST_VERSION   2.0.2

#ifndef WO_STRINGIFY
/*!
 *! Stringification macro.
 *!
 *! If \p var is a macro then only its name will be stringified. To stringify
 *! the contents of a macro use WO_STRINGIFY_CONTENTS.
 *!
 *!     \code
 *!     #define FOO bar
 *!     char *foo = WO_STRINGIFY(FOO); // char *foo = "FOO";
 *!     \endcode
 */
#define WO_STRINGIFY(var) #var
#endif

#ifndef WO_STRINGIFY_CONTENTS
/*!
 *! Double-stringification macro.
 *!
 *! If \p var is a macro, stringifies the contents of the macro; if \p var is
 *! not a macro, merely stringifies it.
 *!
 *!     \code
 *!     #define FOO bar
 *!     char *foo = WO_STRINGIFY_CONTENTS(FOO); // char *foo = "bar";
 *!     \endcode
 */
#define WO_STRINGIFY_CONTENTS(var) WO_STRINGIFY(var)
#endif

/*!
 *! Make what(1) produce meaningful output.
 *!
 *! Defines an id string accesible via "rcsid". The "used" attribute prevents
 *! the linker from removing the symbol during dead code stripping.
 */
#define WO_SET_RCSID_STRING(msg, tag) \
        static const char *rcsid_ ## tag __attribute__((used)) = "@(#)" msg

/*!
 *! Convenience macro for accessing a string previously created with
 *! the WO_SET_RCSID_STRING macro. */
#define WO_GET_RCSID_STRING(tag) (rcsid_ ## tag + 4)

#define WO_COPYRIGHT            "Copyright " \
                                WO_STRINGIFY_CONTENTS(WO_COPYRIGHT_YEARS) \
                                " Wincent Colaiuta"
#define WO_MARKETING_VERSION    WO_STRINGIFY_CONTENTS(WO_INFO_PLIST_VERSION)
