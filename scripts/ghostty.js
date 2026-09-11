// The ephemeral transport runs this once per request; the persistent transport
// keeps it running with `serve`. Address the terminal app that owns this
// process tree, rather than whichever instance Launch Services happens to
// resolve for the application name.
ObjC.import("AppKit");

// A supported app: its name, and the four-character codes from its scripting
// dictionary. cmux embeds Ghostty and mirrors Ghostty.sdef's object model
// under its own codes.
var GHOSTTY = {
  name: "ghostty",
  codes: {
    suite: "Ghst",
    frontWindow: "GFWn",
    selectedTab: "GWsT",
    focusedTerminal: "GTfT",
    terminal: "Gtrm",
    target: "GonT",
  },
};
var CMUX = {
  name: "cmux",
  codes: {
    suite: "Cmux",
    frontWindow: "CMFW",
    selectedTab: "CMsT",
    focusedTerminal: "CMfT",
    terminal: "CMtr",
    target: "CMoT",
  },
};

function appFor(bundleID) {
  if (typeof bundleID !== "string") return undefined;
  if (bundleID === "com.mitchellh.ghostty") return GHOSTTY;
  // Release, nightly, rc, staging, and debug builds, including tagged ones.
  if (
    bundleID === "com.cmuxterm.app" ||
    bundleID.indexOf("com.cmuxterm.app.") === 0
  )
    return CMUX;
  return undefined;
}

var owner;
function owningTerminal() {
  if (owner) return owner;
  var pipe = $.NSPipe.pipe;
  var task = $.NSTask.alloc.init;
  task.launchPath = "/bin/ps";
  task.arguments = ["-axo", "pid=,ppid="];
  task.standardOutput = pipe;
  task.launch;
  var data = pipe.fileHandleForReading.readDataToEndOfFile;
  task.waitUntilExit;
  if (task.terminationStatus !== 0)
    throw Error("Could not read the process tree");
  var rows = ObjC.unwrap(
    $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding),
  );
  var parents = {};
  rows.split("\n").forEach(function (row) {
    var pair = row.trim().split(/\s+/);
    parents[Number(pair[0])] = Number(pair[1]);
  });
  // The nearest matching ancestor wins, so Ghostty started from a cmux shell
  // still addresses Ghostty.
  var pid = $.NSProcessInfo.processInfo.processIdentifier;
  while (pid > 1) {
    var running =
      $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);
    var bundleID = running.isNil()
      ? undefined
      : ObjC.unwrap(running.bundleIdentifier);
    var app = appFor(bundleID);
    if (app) return (owner = { pid: pid, bundleID: bundleID, app: app });
    pid = parents[pid];
  }
  throw Error("No owning Ghostty or cmux process found");
}

// Constructing the address ourselves preserves the PID; JXA Application(pid)
// can resolve by bundle.
var D = $.NSAppleEventDescriptor;
function code(s) {
  return (
    ((s.charCodeAt(0) << 24) |
      (s.charCodeAt(1) << 16) |
      (s.charCodeAt(2) << 8) |
      s.charCodeAt(3)) >>>
    0
  );
}

function send(pid, suite, name, params) {
  var event =
    D.appleEventWithEventClassEventIDTargetDescriptorReturnIDTransactionID(
      code(suite),
      code(name),
      D.descriptorWithProcessIdentifier(pid),
      -1,
      0,
    );
  Object.keys(params || {}).forEach(function (key) {
    event.setDescriptorForKeyword(params[key], code(key));
  });
  var error = Ref();
  var reply = event.sendEventWithOptionsTimeoutError(
    $.NSAppleEventSendDefaultOptions,
    1,
    error,
  );
  if (reply.isNil()) throw Error(ObjC.unwrap(error[0].localizedDescription));
  var err = reply.descriptorForKeyword(code("errn"));
  if (!err.isNil() && err.int32Value) {
    var message = reply.descriptorForKeyword(code("errs"));
    throw Error(
      "Apple Event error " +
        err.int32Value +
        (message.isNil() ? "" : ": " + ObjC.unwrap(message.stringValue)),
    );
  }
  return reply.descriptorForKeyword(code("----"));
}

function prop(name, from) {
  var obj = D.recordDescriptor;
  obj.setDescriptorForKeyword(
    D.descriptorWithTypeCode(code("prop")),
    code("want"),
  );
  obj.setDescriptorForKeyword(
    D.descriptorWithEnumCode(code("prop")),
    code("form"),
  );
  obj.setDescriptorForKeyword(
    D.descriptorWithTypeCode(code(name)),
    code("seld"),
  );
  obj.setDescriptorForKeyword(from || D.nullDescriptor, code("from"));
  return obj.coerceToDescriptorType(code("obj "));
}

function terminal(className, id) {
  var obj = D.recordDescriptor;
  obj.setDescriptorForKeyword(
    D.descriptorWithTypeCode(code(className)),
    code("want"),
  );
  obj.setDescriptorForKeyword(
    D.descriptorWithEnumCode(code("ID  ")),
    code("form"),
  );
  obj.setDescriptorForKeyword(D.descriptorWithString(id), code("seld"));
  obj.setDescriptorForKeyword(D.nullDescriptor, code("from"));
  return obj.coerceToDescriptorType(code("obj "));
}

function focusedTerminalID() {
  var host = owningTerminal();
  var codes = host.app.codes;
  // ID of focused terminal / selected tab / front window.
  return ObjC.unwrap(
    send(host.pid, "core", "getd", {
      "----": prop(
        "ID  ",
        prop(
          codes.focusedTerminal,
          prop(codes.selectedTab, prop(codes.frontWindow)),
        ),
      ),
    }).stringValue,
  );
}

function performAction(terminalID, action) {
  var host = owningTerminal();
  var codes = host.app.codes;
  var params = { "----": D.descriptorWithString(action) };
  params[codes.target] = terminal(codes.terminal, terminalID);
  var performed = !!send(host.pid, codes.suite, "PfAc", params).booleanValue;
  // cmux reports goto_split as performed even when no pane lies in that
  // direction, which would hide every edge from smart-splits. Only a focus
  // change proves the move happened. Ghostty answers accurately, and the
  // actions that do not move focus are left alone.
  if (
    performed &&
    host.app.name === "cmux" &&
    action.indexOf("goto_split:") === 0
  )
    return focusedTerminalID() !== terminalID;
  return performed;
}

// Persistent transport requests and replies are one JSON object per line; the
// Lua side is lua/ghostty-smart-splits/transport.lua.
function handle(request) {
  if (request.command === "focused-terminal-id") return focusedTerminalID();
  if (request.command !== "perform")
    throw Error("Unknown command: " + request.command);
  if (
    typeof request.terminalID !== "string" ||
    typeof request.action !== "string"
  ) {
    throw Error("perform needs a terminalID and an action");
  }
  return performAction(request.terminalID, request.action);
}

function respond(line) {
  try {
    // serve() reads bytes as Latin-1; this turns them back into UTF-8 text.
    var result = handle(JSON.parse(decodeURIComponent(escape(line))));
    if (result === undefined || result === null)
      throw Error("Ghostty automation returned no result");
    return {
      ok: true,
      result: String(result).trim(),
    };
  } catch (error) {
    return {
      ok: false,
      error: String((error && error.message) || error),
    };
  }
}

// Staying alive keeps the JavaScript engine, AppKit, and the owning PID loaded
// between requests. Returns when Neovim closes stdin.
function serve() {
  var input = $.NSFileHandle.fileHandleWithStandardInput;
  var output = $.NSFileHandle.fileHandleWithStandardOutput;
  // One Latin-1 character per byte, so a read that ends inside a UTF-8
  // character neither fails to decode nor holds back the lines before it.
  var buffer = "";
  for (;;) {
    // Blocks until bytes arrive; an empty read is EOF. JXA reports
    // NSData.length as a string, so compare it as a number.
    var data = input.availableData;
    if (Number(data.length) === 0) return;
    buffer += ObjC.unwrap(
      $.NSString.alloc.initWithDataEncoding(data, $.NSISOLatin1StringEncoding),
    );
    var newline;
    while ((newline = buffer.indexOf("\n")) !== -1) {
      var line = buffer.slice(0, newline);
      buffer = buffer.slice(newline + 1);
      output.writeData(
        $(JSON.stringify(respond(line)) + "\n").dataUsingEncoding(
          $.NSUTF8StringEncoding,
        ),
      );
    }
  }
}

function run(argv) {
  if (argv[0] === "focused-terminal-id" && argv.length === 1)
    return focusedTerminalID();
  if (argv[0] === "perform-action" && argv.length === 3)
    return performAction(argv[1], argv[2]);
  if (argv[0] === "serve" && argv.length === 1) return serve();
  throw Error(
    "Expected focused-terminal-id, perform-action <terminal ID> <action>, or serve",
  );
}
