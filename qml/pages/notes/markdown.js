.pragma library

// Small Markdown renderer for the rich text item of the Notes page.
//
// Qt 5.12 has no Text.MarkdownText (the ubuntu-sdk-20.04 click build uses that
// version), so the supported subset is converted here to the HTML subset that
// QQuickText understands with textFormat: Text.RichText.
//
// The content comes from the user: every line is escaped before any markup is
// produced, so a note can never inject HTML, and links are restricted to
// http, https and mailto.

function escapeHtml(text) {
    return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
}

function escapeAttribute(text) {
    return escapeHtml(text).replace(/"/g, "&quot;")
}

function safeUrl(url) {
    var trimmed = String(url).trim()
    return /^(https?|mailto):/i.test(trimmed) ? trimmed : ""
}

// Inline markup: code, links, emphasis. The input is already plain text.
function inline(text) {
    var codes = []
    var value = escapeHtml(text)

    // Inline code first: its content must not be interpreted.
    value = value.replace(/`([^`]+)`/g, function (match, code) {
        codes.push(code)
        return "\u0000" + (codes.length - 1) + "\u0000"
    })

    value = value.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (match, label, url) {
        var href = safeUrl(url)
        if (href === "")
            return match
        return '<a href="' + escapeAttribute(href) + '">' + label + '</a>'
    })

    value = value.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
    value = value.replace(/__([^_]+)__/g, "<b>$1</b>")
    value = value.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, "$1<i>$2</i>")
    value = value.replace(/(^|[^_])_([^_\s][^_]*)_/g, "$1<i>$2</i>")
    value = value.replace(/~~([^~]+)~~/g, "<s>$1</s>")

    value = value.replace(/\u0000(\d+)\u0000/g, function (match, index) {
        return "<code>" + codes[parseInt(index)] + "</code>"
    })
    return value
}

function toRichText(markdown) {
    if (!markdown)
        return ""

    var lines = String(markdown).replace(/\r\n?/g, "\n").split("\n")
    var html = []
    var paragraph = []
    var list = ""
    var inCode = false

    function flushParagraph() {
        if (paragraph.length) {
            var rendered = []
            for (var i = 0; i < paragraph.length; i++)
                rendered.push(inline(paragraph[i]))
            html.push("<p>" + rendered.join("<br/>") + "</p>")
            paragraph = []
        }
    }

    function closeList() {
        if (list) {
            html.push("</" + list + ">")
            list = ""
        }
    }

    for (var index = 0; index < lines.length; index++) {
        var line = lines[index]

        if (/^\s*```/.test(line)) {
            if (inCode) {
                html.push("</code></pre>")
                inCode = false
            } else {
                flushParagraph()
                closeList()
                html.push("<pre><code>")
                inCode = true
            }
            continue
        }
        if (inCode) {
            html.push(escapeHtml(line) + "\n")
            continue
        }

        if (/^\s*$/.test(line)) {
            flushParagraph()
            closeList()
            continue
        }

        var heading = line.match(/^(#{1,6})\s+(.*)$/)
        if (heading) {
            flushParagraph()
            closeList()
            var level = heading[1].length
            html.push("<h" + level + ">" + inline(heading[2]) + "</h" + level + ">")
            continue
        }

        if (/^\s*([-*_])\s*\1\s*\1[\s\-*_]*$/.test(line)) {
            flushParagraph()
            closeList()
            html.push("<hr/>")
            continue
        }

        var quote = line.match(/^\s*>\s?(.*)$/)
        if (quote) {
            flushParagraph()
            closeList()
            html.push("<p><i>" + inline(quote[1]) + "</i></p>")
            continue
        }

        var bullet = line.match(/^\s*[-*+]\s+(.*)$/)
        if (bullet) {
            flushParagraph()
            if (list !== "ul") {
                closeList()
                html.push("<ul>")
                list = "ul"
            }
            html.push("<li>" + inline(bullet[1]) + "</li>")
            continue
        }

        var ordered = line.match(/^\s*\d+[.)]\s+(.*)$/)
        if (ordered) {
            flushParagraph()
            if (list !== "ol") {
                closeList()
                html.push("<ol>")
                list = "ol"
            }
            html.push("<li>" + inline(ordered[1]) + "</li>")
            continue
        }

        paragraph.push(line)
    }

    if (inCode)
        html.push("</code></pre>")
    flushParagraph()
    closeList()
    return html.join("")
}
