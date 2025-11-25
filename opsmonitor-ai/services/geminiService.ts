import { GoogleGenAI } from "@google/genai";

// Initialize Gemini Client
const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

export const generateAnsiblePlaybook = async (
  osFamily: string, 
  ip: string, 
  port: string,
  user: string
): Promise<string> => {
  const model = "gemini-2.5-flash";
  
  const prompt = `
    Generate a complete, valid Ansible Playbook (YAML) to install Prometheus Node Exporter.
    Target OS Family: ${osFamily}
    Target Host: ${ip}
    Connection Port: ${port}
    User: ${user}
    
    Requirements:
    1. If Linux (General):
       - The playbook must detect the package manager (apt vs yum/dnf) automatically using 'when' conditions or 'ansible_facts'.
       - Create a 'node_exporter' user.
       - Download the latest Node Exporter binary suitable for the architecture.
       - Extract and move binary to /usr/local/bin.
       - Create a systemd service file for node_exporter.
       - Start and enable the service.
    
    2. If Windows:
       - Use 'win_chocolatey' or 'win_package' to install 'prometheus-node-exporter.install'.
       - Ensure the service is started.
       - Configure firewall to allow port 9100.
    
    Return ONLY the YAML code block. Do not include markdown formatting like \`\`\`yaml.
  `;

  try {
    const response = await ai.models.generateContent({
      model: model,
      contents: prompt,
    });
    
    let text = response.text || "";
    // Clean up if the model adds markdown ticks despite instructions
    text = text.replace(/```yaml/g, '').replace(/```/g, '').trim();
    return text;
  } catch (error) {
    console.error("Gemini Ansible Generation Error:", error);
    return "# Error generating playbook. Please check API Key.";
  }
};

export const generatePrometheusConfig = async (ip: string, port: string, name: string): Promise<string> => {
  const model = "gemini-2.5-flash";
  const prompt = `
    Generate a Prometheus 'scrape_config' job entry (YAML) for a new target.
    Job Name: ${name}
    Target: ${ip}:9100
    (Note: The node exporter runs on 9100, the connection port provided was ${port} but that is for management)
    
    Return ONLY the YAML snippet. No markdown.
  `;

  try {
    const response = await ai.models.generateContent({
      model: model,
      contents: prompt,
    });
    
    let text = response.text || "";
    text = text.replace(/```yaml/g, '').replace(/```/g, '').trim();
    return text;
  } catch (error) {
    console.error("Gemini Config Generation Error:", error);
    return "# Error generating config.";
  }
};

export const analyzeSystemLogs = async (logs: string): Promise<string> => {
   const model = "gemini-2.5-flash";
   try {
    const response = await ai.models.generateContent({
      model: model,
      contents: `Analyze these system logs and provide a 1-sentence summary of the health status: ${logs}`,
    });
    return response.text || "Analysis complete.";
   } catch (error) {
     return "Unable to analyze logs.";
   }
}