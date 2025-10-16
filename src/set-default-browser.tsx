import { environment, List, ActionPanel, Action, showToast, Toast, Icon, closeMainWindow, popToRoot } from "@raycast/api";
import { execFile } from "child_process";
import { promisify } from "util";
import { useState, useEffect } from "react";
import path from "path";

const execFileAsync = promisify(execFile);

interface Browser {
  id: string;
  name: string;
  isDefault: boolean;
}

export default function Command() {
  const [browsers, setBrowsers] = useState<Browser[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  async function loadBrowsers() {
    setIsLoading(true);
    try {
      const scriptPath = path.join(environment.assetsPath, "defbrowser.swift");
      const { stdout } = await execFileAsync("swift", [scriptPath, "--list-json"]);
      const browserList = JSON.parse(stdout) as Browser[];
      setBrowsers(browserList);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load browsers",
        message: String(error),
      });
    } finally {
      setIsLoading(false);
    }
  }

  async function setDefaultBrowser(bundleId: string, name: string) {
    try {
      const toast = await showToast({
        style: Toast.Style.Animated,
        title: `Setting ${name} as default...`,
      });
      const scriptPath = path.join(environment.assetsPath, "defbrowser.swift");
      await execFileAsync("swift", [scriptPath, bundleId]);
      toast.style = Toast.Style.Success;
      toast.title = `${name} is now the default browser`;
      await closeMainWindow({ clearRootSearch: true });
      await popToRoot();
    } catch (error: unknown) {
      let message = "Unknown error";
      if (typeof error === "object" && error !== null) {
        const rec = error as Record<string, unknown>;
        const stderr = typeof rec.stderr === "string" ? rec.stderr.trim() : "";
        const stdout = typeof rec.stdout === "string" ? rec.stdout.trim() : "";
        const baseMsg = typeof rec.message === "string" ? rec.message : "";
        message = stderr || baseMsg || stdout || message;
      } else if (typeof error === "string") {
        message = error;
      }
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to set default browser",
        message: message,
      });
    }
  }

  useEffect(() => {
    loadBrowsers();
  }, []);

  return (
    <List isLoading={isLoading}>
      {browsers.map((browser) => (
        <List.Item
          key={browser.id}
          title={browser.name}
          subtitle={browser.id}
          icon={browser.isDefault ? Icon.CheckCircle : Icon.Circle}
          accessories={[{ text: browser.isDefault ? "Default" : "" }]}
          actions={
            <ActionPanel>
              <Action
                title="Set as Default Browser"
                onAction={() => setDefaultBrowser(browser.id, browser.name)}
                icon={Icon.CheckCircle}
              />
              <Action title="Refresh List" onAction={loadBrowsers} icon={Icon.RotateClockwise} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
