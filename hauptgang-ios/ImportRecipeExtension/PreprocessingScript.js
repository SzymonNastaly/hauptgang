var Action = function() {};

Action.prototype = {
    run: function(parameters) {
        try {
            var result = {};

            // URL
            result.url = window.location.href;

            // JSON-LD blocks — all <script type="application/ld+json"> contents as raw strings
            var jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
            var jsonLdBlocks = [];
            for (var i = 0; i < jsonLdScripts.length; i++) {
                var text = jsonLdScripts[i].textContent;
                if (text && text.trim().length > 0) {
                    var trimmed = text.trim();
                    try {
                        var parsed = JSON.parse(trimmed);
                        var sanitized = stripReviewFields(parsed);
                        jsonLdBlocks.push(JSON.stringify(sanitized));
                    } catch (e) {
                        // Keep original block if parsing fails
                        jsonLdBlocks.push(trimmed);
                    }
                }
            }
            result.jsonLd = jsonLdBlocks;

            // Meta tags
            var metaTags = {};
            var ogTags = ["og:title", "og:image", "og:image:secure_url", "og:description"];
            for (var j = 0; j < ogTags.length; j++) {
                var el = document.querySelector('meta[property="' + ogTags[j] + '"]');
                if (el) {
                    metaTags[ogTags[j]] = el.getAttribute("content") || "";
                }
            }
            var twitterImageEl = document.querySelector('meta[name="twitter:image"]');
            if (twitterImageEl) {
                metaTags["twitter:image"] = twitterImageEl.getAttribute("content") || "";
            }
            var descEl = document.querySelector('meta[name="description"]');
            if (descEl) {
                metaTags["description"] = descEl.getAttribute("content") || "";
            }
            result.metaTags = metaTags;
            result.coverImageCandidates = extractCoverImageCandidates(document);

            // Cleaned HTML — remove non-content elements and noisy attributes
            var clone = document.documentElement.cloneNode(true);
            var removeTags = [
                "script", "style", "nav", "header", "footer", "aside", "svg", "iframe", "noscript",
                "video", "button", "form", "input", "select", "option", "textarea", "label",
                "canvas", "picture", "source", "template", "dialog"
            ];
            for (var k = 0; k < removeTags.length; k++) {
                var elements = clone.querySelectorAll(removeTags[k]);
                for (var m = 0; m < elements.length; m++) {
                    elements[m].parentNode.removeChild(elements[m]);
                }
            }

            // Remove HTML comments
            var commentWalker = document.createTreeWalker(clone, NodeFilter.SHOW_COMMENT, null, false);
            var commentsToRemove = [];
            while (commentWalker.nextNode()) {
                commentsToRemove.push(commentWalker.currentNode);
            }
            for (var c = 0; c < commentsToRemove.length; c++) {
                if (commentsToRemove[c].parentNode) {
                    commentsToRemove[c].parentNode.removeChild(commentsToRemove[c]);
                }
            }

            // Strip noisy attributes
            var allElements = clone.querySelectorAll("*");
            for (var n = 0; n < allElements.length; n++) {
                var el = allElements[n];
                var attrs = el.attributes;
                var toRemove = [];
                for (var p = 0; p < attrs.length; p++) {
                    var name = attrs[p].name;
                    if (
                        name === "class" ||
                        name === "style" ||
                        name === "id" ||
                        name === "srcset" ||
                        name === "poster" ||
                        name === "autoplay" ||
                        name === "controls" ||
                        name === "loading" ||
                        name === "decoding" ||
                        name.indexOf("data-") === 0 ||
                        name.indexOf("aria-") === 0 ||
                        name.indexOf("on") === 0
                    ) {
                        toRemove.push(name);
                    }
                }
                for (var q = 0; q < toRemove.length; q++) {
                    el.removeAttribute(toRemove[q]);
                }
            }

            // Remove whitespace-only text nodes
            var textWalker = document.createTreeWalker(clone, NodeFilter.SHOW_TEXT, null, false);
            var textNodesToRemove = [];
            while (textWalker.nextNode()) {
                if (!textWalker.currentNode.nodeValue || textWalker.currentNode.nodeValue.trim().length === 0) {
                    textNodesToRemove.push(textWalker.currentNode);
                }
            }
            for (var t = 0; t < textNodesToRemove.length; t++) {
                if (textNodesToRemove[t].parentNode) {
                    textNodesToRemove[t].parentNode.removeChild(textNodesToRemove[t]);
                }
            }

            // Remove empty elements (iterate backwards so nested empties get removed)
            var allForPrune = clone.querySelectorAll("*");
            for (var r = allForPrune.length - 1; r >= 0; r--) {
                var pruneEl = allForPrune[r];
                if (pruneEl.children.length === 0 && (!pruneEl.textContent || pruneEl.textContent.trim().length === 0)) {
                    if (pruneEl.parentNode) {
                        pruneEl.parentNode.removeChild(pruneEl);
                    }
                }
            }

            // Send only <body> HTML since URL/meta/JSON-LD are sent separately
            result.html = clone.body ? clone.body.outerHTML : clone.outerHTML;

            parameters.completionFunction(result);
        } catch (e) {
            // If anything fails, at least return the URL so the fallback can work
            parameters.completionFunction({ "url": window.location.href, "error": e.toString() });
        }
    },

    finalize: function(parameters) {}
};

function stripReviewFields(value) {
    if (Array.isArray(value)) {
        var arr = [];
        for (var i = 0; i < value.length; i++) {
            arr.push(stripReviewFields(value[i]));
        }
        return arr;
    }

    if (value && typeof value === "object") {
        var output = {};
        for (var key in value) {
            if (!Object.prototype.hasOwnProperty.call(value, key)) {
                continue;
            }
            if (key === "review" || key === "aggregateRating") {
                continue;
            }
            output[key] = stripReviewFields(value[key]);
        }
        return output;
    }

    return value;
}

function extractCoverImageCandidates(doc) {
    var images = doc.querySelectorAll("img");
    var scored = {};

    for (var i = 0; i < images.length; i++) {
        var img = images[i];
        var rect = img.getBoundingClientRect ? img.getBoundingClientRect() : null;
        var width = rect && rect.width ? rect.width : 0;
        var height = rect && rect.height ? rect.height : 0;
        if ((width < 64 || height < 64) && (img.naturalWidth < 64 || img.naturalHeight < 64)) {
            continue;
        }
        if (!isImageVisible(img, rect)) {
            continue;
        }

        var top = rect ? rect.top : 0;
        var pageTop = top + (window.scrollY || 0);
        var area = Math.max(width, img.naturalWidth || 0) * Math.max(height, img.naturalHeight || 0);
        var topPenalty = Math.max(0, pageTop) * 0.2;
        var score = Math.min(area, 2000000) / 1000 - topPenalty;
        if (top >= 0 && top < window.innerHeight * 1.5) {
            score += 120;
        }

        var urls = collectImageURLs(img);
        for (var u = 0; u < urls.length; u++) {
            var key = urls[u];
            if (!scored[key] || scored[key] < score) {
                scored[key] = score;
            }
        }
    }

    var ranked = [];
    for (var url in scored) {
        if (Object.prototype.hasOwnProperty.call(scored, url)) {
            ranked.push({ url: url, score: scored[url] });
        }
    }

    ranked.sort(function(a, b) { return b.score - a.score; });
    var candidates = [];
    var maxCandidates = 5;
    for (var r = 0; r < ranked.length && r < maxCandidates; r++) {
        candidates.push(ranked[r].url);
    }
    return candidates;
}

function isImageVisible(img, rect) {
    if (!rect) {
        return false;
    }
    if (rect.width <= 0 || rect.height <= 0) {
        return false;
    }
    var style = window.getComputedStyle ? window.getComputedStyle(img) : null;
    if (style && (style.display === "none" || style.visibility === "hidden" || style.opacity === "0")) {
        return false;
    }
    return true;
}

function collectImageURLs(img) {
    var urls = [];
    pushCandidateURL(urls, img.currentSrc);
    pushCandidateURL(urls, img.getAttribute("src"));

    var srcset = img.getAttribute("srcset");
    if (srcset) {
        var bestFromSrcset = bestSrcsetURL(srcset);
        pushCandidateURL(urls, bestFromSrcset);
    }
    return urls;
}

function bestSrcsetURL(srcset) {
    var entries = srcset.split(",");
    var bestURL = null;
    var bestRank = -1;

    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i].trim();
        if (!entry) {
            continue;
        }

        var parts = entry.split(/\s+/);
        var rawURL = parts[0];
        var descriptor = parts.length > 1 ? parts[1] : "";
        var rank = 1;

        if (descriptor) {
            var widthMatch = descriptor.match(/^(\d+)w$/);
            var densityMatch = descriptor.match(/^(\d+(?:\.\d+)?)x$/);
            if (widthMatch) {
                rank = parseInt(widthMatch[1], 10);
            } else if (densityMatch) {
                rank = Math.round(parseFloat(densityMatch[1]) * 1000);
            }
        }

        if (rank > bestRank) {
            bestRank = rank;
            bestURL = rawURL;
        }
    }

    return bestURL;
}

function pushCandidateURL(collection, rawURL) {
    var normalized = normalizeCandidateURL(rawURL);
    if (!normalized) {
        return;
    }
    if (collection.indexOf(normalized) === -1) {
        collection.push(normalized);
    }
}

function normalizeCandidateURL(rawURL) {
    if (!rawURL) {
        return null;
    }
    var trimmed = String(rawURL).trim();
    if (!trimmed || trimmed.indexOf("data:") === 0 || trimmed.indexOf("blob:") === 0) {
        return null;
    }
    try {
        var absolute = new URL(trimmed, window.location.href);
        var scheme = absolute.protocol.toLowerCase();
        if (scheme !== "http:" && scheme !== "https:") {
            return null;
        }
        return absolute.toString();
    } catch (e) {
        return null;
    }
}

var ExtensionPreprocessingJS = new Action();
