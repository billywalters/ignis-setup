// src/context/SysInfoContext.js
// Single source of truth for the system info React context.
// Both the provider (App.jsx) and any consumer (panels, pages) import from here
// to avoid importing from App.jsx and risking circular dependencies.

import React from "react";

const SysInfoContext = React.createContext(null);

export default SysInfoContext;
