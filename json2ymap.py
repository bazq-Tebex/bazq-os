import json
import math
import os
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext
from tkinter import ttk

# Default configuration
DEFAULT_INPUT_FILE = 'saved_objects.json'
DEFAULT_OUTPUT_FILE = 'converted.ymap.xml'
YMAP_NAME = 'converted_objects'

# Default values for YMAP entities
DEFAULT_FLAGS = 32 # 32 is standard for static entities
DEFAULT_LOD_DIST = 200

class JsonToYmapApp:
    def __init__(self, root):
        self.root = root
        self.root.title("bazq JSON to YMAP Converter")
        self.root.geometry("600x500")
        
        # Style configuration
        self.configure_styles()

        # Build UI
        self.create_widgets()
        
        # Load default if exists
        self.check_default_files()

    def configure_styles(self):
        style = ttk.Style()
        style.theme_use('clam')
        
        # Dark theme colors
        bg_color = "#2d2d2d"
        fg_color = "#ffffff"
        entry_bg = "#3d3d3d"
        button_bg = "#007acc"
        
        self.root.configure(bg=bg_color)
        
        style.configure("TFrame", background=bg_color)
        style.configure("TLabel", background=bg_color, foreground=fg_color, font=("Segoe UI", 10))
        style.configure("TButton", background=button_bg, foreground=fg_color, font=("Segoe UI", 10, "bold"), padding=6)
        style.map("TButton", background=[('active', '#005f9e')])
        
        style.configure("TEntry", fieldbackground=entry_bg, foreground=fg_color)

    def create_widgets(self):
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # Header
        header_label = ttk.Label(main_frame, text="JSON ➔ YMAP Converter", font=("Segoe UI", 16, "bold"))
        header_label.pack(pady=(0, 20))

        # Input File Section
        input_frame = ttk.Frame(main_frame)
        input_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(input_frame, text="Input JSON File:").pack(anchor=tk.W)
        
        self.input_entry = ttk.Entry(input_frame)
        self.input_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 10))
        
        browse_input_btn = ttk.Button(input_frame, text="Browse", command=self.browse_input)
        browse_input_btn.pack(side=tk.RIGHT)

        # Output File Section
        output_frame = ttk.Frame(main_frame)
        output_frame.pack(fill=tk.X, pady=15)
        
        ttk.Label(output_frame, text="Output YMAP File:").pack(anchor=tk.W)
        
        self.output_entry = ttk.Entry(output_frame)
        self.output_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 10))
        
        browse_output_btn = ttk.Button(output_frame, text="Save As", command=self.browse_output)
        browse_output_btn.pack(side=tk.RIGHT)

        # Convert Button
        self.convert_btn = ttk.Button(main_frame, text="START CONVERSION", command=self.convert)
        self.convert_btn.pack(pady=20, fill=tk.X)

        # Log Area
        ttk.Label(main_frame, text="Conversion Log:").pack(anchor=tk.W)
        self.log_area = scrolledtext.ScrolledText(main_frame, height=10, bg="#1e1e1e", fg="#00ff00", font=("Consolas", 9))
        self.log_area.pack(fill=tk.BOTH, expand=True)
        self.log_area.insert(tk.END, "Ready to convert...\n")

    def log(self, message):
        self.log_area.insert(tk.END, f"> {message}\n")
        self.log_area.see(tk.END)

    def check_default_files(self):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        default_input = os.path.join(script_dir, DEFAULT_INPUT_FILE)
        
        if os.path.exists(default_input):
            self.input_entry.insert(0, default_input)
            self.log(f"Detected {DEFAULT_INPUT_FILE} automatically.")
        
        self.output_entry.insert(0, os.path.join(script_dir, DEFAULT_OUTPUT_FILE))

    def browse_input(self):
        filename = filedialog.askopenfilename(
            title="Select Input JSON",
            filetypes=[("JSON Files", "*.json"), ("All Files", "*.*")]
        )
        if filename:
            self.input_entry.delete(0, tk.END)
            self.input_entry.insert(0, filename)

    def browse_output(self):
        filename = filedialog.asksaveasfilename(
            title="Select Output XML",
            defaultextension=".xml",
            filetypes=[("YMAP XML Files", "*.ymap.xml"), ("XML Files", "*.xml"), ("All Files", "*.*")]
        )
        if filename:
            self.output_entry.delete(0, tk.END)
            self.output_entry.insert(0, filename)

    def euler_to_quaternion(self, heading_degrees):
        radians = math.radians(heading_degrees)
        half_angle = radians * 0.5
        
        qx = 0.0
        qy = 0.0
        qz = math.sin(half_angle)
        qw = math.cos(half_angle)
        
        length = math.sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
        if length != 0:
            qx /= length
            qy /= length
            qz /= length
            qw /= length
            
        return qx, qy, qz, qw

    def convert(self):
        input_path = self.input_entry.get()
        output_path = self.output_entry.get()
        
        if not input_path or not output_path:
            messagebox.showerror("Error", "Please specify both input and output files.")
            return

        self.log(f"Reading from: {input_path}")
        
        try:
            with open(input_path, 'r', encoding='utf-8') as f:
                objects = json.load(f)
        except Exception as e:
            self.log(f"Error reading JSON: {e}")
            messagebox.showerror("Error", f"Failed to read JSON: {e}")
            return

        object_count = len(objects)
        self.log(f"Found {object_count} objects. Processing...")
        
        # Performance check
        if object_count > 1500:
            messagebox.showwarning(
                "High Object Count", 
                f"You are converting {object_count} objects!\n\n"
                "This might cause lag in-game or during streaming.\n"
                "Recommendation: Split your work into multiple JSON/YMAP files."
            )
            self.log("WARNING: High object count detected (>1500). Consider splitting.")

        if not objects:
            min_x = min_y = min_z = 0
            max_x = max_y = max_z = 0
        else:
            min_x = min_y = min_z = float('inf')
            max_x = max_y = max_z = float('-inf')

        entities_xml = ""
        count = 0
        
        for obj in objects:
            try:
                model = obj.get('model', 'unknown_model')
                coords = obj.get('coords', {})
                x = float(coords.get('x', 0))
                y = float(coords.get('y', 0))
                z = float(coords.get('z', 0))
                heading = float(obj.get('heading', 0))
                
                # Update Extents
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                min_z = min(min_z, z)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                max_z = max(max_z, z)

                # Calculate Rotation
                qx, qy, qz, qw = self.euler_to_quaternion(-heading) 

                # Determine flags
                # Special flag for doors/gates/kapi (1572864)
                # Default flag (32)
                flags = 32
                lname = model.lower()
                if any(x in lname for x in ['gate', 'door', 'kapi', 'sur_mkapi']):
                    flags = 1572864
                
                # Exception: bazq-sur_kapi is a doorframe (static), so revert to 32
                if 'bazq-sur_kapi' in lname:
                    flags = 32

                item_xml = f"""  <Item type="CEntityDef">
   <archetypeName>{model}</archetypeName>
   <flags value="{flags}" />
   <guid value="0" />
   <position x="{x:.6f}" y="{y:.6f}" z="{z:.6f}" />
   <rotation x="{qx:.7f}" y="{qy:.7f}" z="{qz:.7f}" w="{qw:.7f}" />
   <scaleXY value="1" />
   <scaleZ value="1" />
   <parentIndex value="-1" />
   <lodDist value="{DEFAULT_LOD_DIST}" />
   <childLodDist value="0" />
   <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>
   <numChildren value="0" />
   <priorityLevel>PRI_REQUIRED</priorityLevel>
   <extensions />
   <ambientOcclusionMultiplier value="255" />
   <artificialAmbientOcclusion value="255" />
   <tintValue value="0" />
  </Item>
"""
                entities_xml += item_xml
                count += 1
            except Exception as ex:
                self.log(f"Skipping error object: {ex}")
                continue

        PADDING = 400.0
        s_min_x = min_x - PADDING
        s_min_y = min_y - PADDING
        s_min_z = min_z - PADDING
        s_max_x = max_x + PADDING
        s_max_y = max_y + PADDING
        s_max_z = max_z + PADDING

        ymap_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<CMapData>
 <name>{YMAP_NAME}</name>
 <parent />
 <flags value="0" />
 <contentFlags value="1" />
 <streamingExtentsMin x="{s_min_x:.4f}" y="{s_min_y:.4f}" z="{s_min_z:.4f}" />
 <streamingExtentsMax x="{s_max_x:.4f}" y="{s_max_y:.4f}" z="{s_max_z:.4f}" />
 <entitiesExtentsMin x="{min_x:.4f}" y="{min_y:.4f}" z="{min_z:.4f}" />
 <entitiesExtentsMax x="{max_x:.4f}" y="{max_y:.4f}" z="{max_z:.4f}" />
 <entities>
{entities_xml} </entities>
</CMapData>"""

        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(ymap_content)
            self.log(f"SUCCESS! Wrote {count} entities to file.")
            self.log(f"Output saved to: {output_path}")
            messagebox.showinfo("Success", f"Conversion Complete!\nSaved {count} objects to YMAP.")
        except Exception as e:
            self.log(f"Error writing file: {e}")
            messagebox.showerror("Error", f"Failed to write YMAP: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Keep CLI support if args provided (optional, simplified here to just launch GUI usually)
        # But for this task, force GUI as requested.
        pass
    
    root = tk.Tk()
    app = JsonToYmapApp(root)
    root.mainloop()
