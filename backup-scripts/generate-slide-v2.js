#!/usr/bin/env node
/**
 * Components Bay — Slide Generator v2
 * ASM template background + dark sidebar + professional table layout
 */

const pptxgen = require("pptxgenjs");
const https   = require("https");
const path    = require("path");
const fs      = require("fs");

const SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI";

const today = new Date().toISOString().slice(0, 10);

// Background image (ASM template) — embedded as base64
const BG_PATH = path.join(__dirname, "asm_slide_bg.png");
let bgBase64 = null;
if (fs.existsSync(BG_PATH)) {
  bgBase64 = "image/png;base64," + fs.readFileSync(BG_PATH).toString("base64");
} else {
  console.warn("Warning: asm_slide_bg.png not found, using plain background.");
}

let OUTPUT_DIR = "C:\\Users\\jpellegrini\\Desktop\\APP 5.5";
if (!fs.existsSync(OUTPUT_DIR)) OUTPUT_DIR = "C:\\ComponentsBay_Logs";
if (!fs.existsSync(OUTPUT_DIR)) OUTPUT_DIR = path.join(__dirname, ".");
const OUTPUT = path.join(OUTPUT_DIR, `Component_Bay_Slide_${today}.pptx`);

// ─── Design ─────────────────────────────────────────────────────────────────
const D = {
  navy:"1B2B4B", white:"FFFFFF", silver:"F0F4F8", rowAlt:"E8EEF5",
  border:"CBD5E1", text:"1E293B", subtext:"475569",
  green:"15803D", orange:"B45309", crimson:"991B1B", amber:"D4900A",
};
const W = 13.33, H = 7.5, SB = 2.55, TY = 1.05;

function makeShadow() { return {type:"outer",color:"000000",blur:8,offset:2,angle:135,opacity:0.18}; }
function dayColor(v) { const d=parseInt(v); if(isNaN(d)) return D.text; if(d<=30) return D.crimson; if(d<=60) return D.orange; return D.green; }
function trunc(s,n=32){s=String(s||"");return s.length>n?s.slice(0,n)+"…":s;}

// ─── HTTP fetch ──────────────────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url,{headers:{apikey:SUPABASE_KEY,Authorization:`Bearer ${SUPABASE_KEY}`}},res=>{
      let d=""; res.on("data",c=>d+=c); res.on("end",()=>{try{resolve(JSON.parse(d));}catch(e){reject(e);}});
    }).on("error",reject);
  });
}
async function fetchTable(t) {
  const rows = await fetchJson(`${SUPABASE_URL}/rest/v1/${t}?select=*`);
  return rows.map(r=>{let d=r.data||{};if(typeof d==="string")d=JSON.parse(d);return d;});
}
function daysLeft(s){if(!s)return null;const d=Math.round((new Date(String(s).slice(0,10))-new Date())/86400000);return isNaN(d)?null:d;}

// ─── Slide builder ───────────────────────────────────────────────────────────
function buildSlide(prs, {accent, title, subtitle, headerLabel, count, headers, rows, colW, daysCol=-1}) {
  const slide = prs.addSlide();

  // Background
  if (bgBase64) {
    slide.addImage({data:bgBase64, x:0, y:0, w:W, h:H});
  } else {
    slide.background = {color:"F2F0EE"};
  }

  // Mask template text ("Flying Plan..." and page number)
  slide.addShape(prs.shapes.RECTANGLE, {x:0,y:0.60,w:6.5,h:0.55,fill:{color:"F2F0EE"},line:{color:"F2F0EE"}});
  slide.addShape(prs.shapes.RECTANGLE, {x:12.5,y:7.1,w:0.85,h:0.4,fill:{color:"1B2A3E"},line:{color:"1B2A3E"}});

  // Sidebar
  slide.addShape(prs.shapes.RECTANGLE, {x:0.32,y:TY,w:SB,h:H-TY-0.68,fill:{color:D.navy},line:{color:D.navy},shadow:makeShadow()});
  slide.addShape(prs.shapes.RECTANGLE, {x:0.32,y:TY,w:SB,h:0.07,fill:{color:accent},line:{color:accent}});
  slide.addText(String(count),{x:0.32,y:TY+0.12,w:SB,h:1.35,fontSize:78,bold:true,color:accent,align:"center",valign:"middle",fontFace:"Calibri"});
  slide.addShape(prs.shapes.RECTANGLE, {x:0.52,y:TY+1.55,w:SB-0.4,h:0.02,fill:{color:accent},line:{color:accent}});
  slide.addText(title.toUpperCase(),{x:0.32,y:TY+1.62,w:SB,h:1.15,fontSize:17,bold:true,color:D.white,align:"center",valign:"top",fontFace:"Calibri",charSpacing:2,wrap:true});
  const PY=TY+2.95;
  slide.addShape(prs.shapes.RECTANGLE, {x:0.52,y:PY,w:SB-0.4,h:0.52,fill:{color:accent},line:{color:accent},shadow:{type:"outer",color:"000000",blur:6,offset:2,angle:135,opacity:0.25}});
  slide.addText(subtitle,{x:0.52,y:PY,w:SB-0.4,h:0.52,fontSize:10,bold:true,color:D.white,align:"center",valign:"middle",fontFace:"Calibri",charSpacing:1,margin:0});
  slide.addText(today,{x:0.32,y:H-0.88,w:SB,h:0.22,fontSize:7.5,color:D.subtext,align:"center",fontFace:"Calibri"});

  // Table panel
  const TTX=0.32+SB+0.18, TTW=W-TTX-0.32;
  slide.addShape(prs.shapes.RECTANGLE, {x:TTX,y:TY,w:TTW,h:H-TY-0.68,fill:{color:D.white,transparency:5},line:{color:D.border,width:0.5},shadow:makeShadow()});

  // Header bar
  const BH=0.40;
  slide.addShape(prs.shapes.RECTANGLE, {x:TTX,y:TY,w:TTW,h:BH,fill:{color:accent},line:{color:accent}});
  slide.addShape(prs.shapes.OVAL, {x:TTX+0.10,y:TY+0.08,w:0.24,h:0.24,fill:{color:D.white,transparency:75},line:{color:D.white,width:1}});
  slide.addText("!",{x:TTX+0.10,y:TY+0.08,w:0.24,h:0.24,fontSize:10,bold:true,color:D.white,align:"center",valign:"middle",margin:0});
  slide.addText(headerLabel,{x:TTX+0.42,y:TY,w:TTW-1.6,h:BH,fontSize:9.5,bold:true,color:D.white,align:"left",valign:"middle",fontFace:"Calibri",charSpacing:0.5,margin:0});
  slide.addShape(prs.shapes.RECTANGLE, {x:TTX+TTW-1.1,y:TY+0.06,w:0.95,h:BH-0.12,fill:{color:D.white,transparency:80},line:{color:D.white,width:0.5}});
  slide.addText(String(count),{x:TTX+TTW-1.1,y:TY+0.06,w:0.95,h:BH-0.12,fontSize:14,bold:true,color:D.white,align:"center",valign:"middle",margin:0});

  // Column headers
  const HY=TY+BH, HH=0.27; let cx=TTX;
  headers.forEach((h,i)=>{
    slide.addShape(prs.shapes.RECTANGLE, {x:cx,y:HY,w:colW[i],h:HH,fill:{color:D.navy},line:{color:D.border,width:0.4}});
    slide.addText(h,{x:cx+0.05,y:HY,w:colW[i]-0.1,h:HH,fontSize:7.5,bold:true,color:D.amber,align:"left",valign:"middle",fontFace:"Calibri",charSpacing:1.5,margin:0});
    cx+=colW[i];
  });

  // Rows
  const DY=HY+HH, DH=H-DY-0.72, rh=Math.min(DH/rows.length,0.265);
  rows.forEach((row,ri)=>{
    const ry=DY+ri*rh, bg=ri%2===0?D.white:D.silver; cx=TTX;
    row.forEach((cell,ci)=>{
      const txt=String(cell||""); let fg=D.text, bold=false;
      if(ci===daysCol&&txt){fg=dayColor(txt);bold=true;}
      slide.addShape(prs.shapes.RECTANGLE, {x:cx,y:ry,w:colW[ci],h:rh,fill:{color:bg},line:{color:D.border,width:0.25}});
      slide.addText(txt,{x:cx+0.06,y:ry,w:colW[ci]-0.12,h:rh,fontSize:7.5,color:fg,bold:bold,fontFace:"Calibri",align:"left",valign:"middle",margin:0,shrinkText:true});
      cx+=colW[ci];
    });
  });
  slide.addShape(prs.shapes.RECTANGLE, {x:TTX,y:DY+rows.length*rh,w:TTW,h:0.025,fill:{color:accent},line:{color:accent}});
}

// ─── Main ────────────────────────────────────────────────────────────────────
async function main() {
  console.log("=".repeat(55));
  console.log("  Components Bay — Slide Generator v2");
  console.log(`  ${today}`);
  console.log("=".repeat(55));
  console.log("\nLoading data from Supabase...");

  let efs,efsCyl,liferafts,maint,comp,avio,eng,rotor,iaft,pol,tools,troop;
  try {
    [efs,efsCyl,liferafts,maint,comp,avio,eng,rotor,iaft,pol,tools,troop] = await Promise.all([
      fetchTable("efs"),fetchTable("efs_cylinders"),fetchTable("liferafts"),
      fetchTable("maintenance"),fetchTable("composite"),fetchTable("avionic"),
      fetchTable("engine"),fetchTable("rotorbay"),fetchTable("iafteaft"),
      fetchTable("pol"),fetchTable("tools"),fetchTable("troopseats"),
    ]);
  } catch(e){console.error("Supabase error:",e.message);process.exit(1);}

  const s1=[];
  for(const[mod,items]of[["Maintenance",maint],["Composite",comp],["Avionic",avio],["Engine",eng],["Rotor Bay",rotor],["IAFT/EAFT",iaft],["POL",pol],["Tools",tools],["Troop Seat",troop],["EFS Float",efs],["EFS Cyl.",efsCyl]]){
    for(const it of items)if(it.serviceability==="Unserviceable"){const pn=it.pnWheel||it.partNumber||"";s1.push([mod,trunc(it.designation||"",28),trunc(pn,18),it.serialNumber||"",trunc(it.reason||"Unserviceable",28)]);}
  }
  const s2=[];
  for(const it of liferafts)if(it.serviceability==="Unserviceable")s2.push([it.partNumber||"",it.serialNumber||"",trunc(it.reason||"Unserviceable",36)]);

  const s3=[];
  for(const it of efs){if(it.serviceability==="Unserviceable")continue;let best=999;for(const f of["next18M","next36M"]){const d=daysLeft(it[f]);if(d!==null&&d>=0&&d<=90&&d<best)best=d;}if(best<999)s3.push([it.hc||"",trunc(it.designation||"",22),it.partNumber||"",it.serialNumber||"",it.next18M||"",it.next36M||"",`${best}d`]);}
  s3.sort((a,b)=>parseInt(a[6])-parseInt(b[6]));

  const s4=[];
  for(const it of efsCyl){if(it.serviceability==="Unserviceable")continue;let best=999;for(const f of["next18M","next60M"]){const d=daysLeft(it[f]);if(d!==null&&d>=0&&d<=90&&d<best)best=d;}if(best<999)s4.push([it.hc||"",trunc(it.designation||"",22),it.partNumber||"",it.serialNumber||"",it.next18M||"",it.next60M||"",`${best}d`]);}
  s4.sort((a,b)=>parseInt(a[6])-parseInt(b[6]));

  console.log(`  Slide 1 — Other Parts U/S:        ${s1.length} items`);
  console.log(`  Slide 2 — Life Raft U/S:           ${s2.length} items`);
  console.log(`  Slide 3 — EFS due <90d:            ${s3.length} items`);
  console.log(`  Slide 4 — EFS Cylinders due <90d:  ${s4.length} items`);

  const cw1=[1.30,2.20,1.95,0.90,3.61];
  const cw2=[1.85,3.22,4.89];
  const cw34=[1.30,2.05,1.90,0.78,1.35,1.35,1.23];

  const prs=new pptxgen();
  prs.layout="LAYOUT_WIDE";
  prs.title=`Components Bay — ${today}`;
  prs.author="ASM";

  buildSlide(prs,{accent:"C0392B",title:"Other Parts",subtitle:"NEED TO BE C/OUT",headerLabel:"ALL UNSERVICEABLE ITEMS (ORDERED)",count:s1.length,headers:["MODULE","DESIGNATION","P/N","S/N","REASON"],rows:s1,colW:cw1});
  buildSlide(prs,{accent:"C0392B",title:"Life Raft",subtitle:"NEED TO BE C/OUT",headerLabel:"LIFE RAFT — NEED TO BE C/OUT",count:s2.length,headers:["P/N","S/N","REASON"],rows:s2,colW:cw2});
  buildSlide(prs,{accent:"1E6BB5",title:"EFS",subtitle:"DUE WITHIN 90 DAYS",headerLabel:"SERVICEABLE EFS — DUE WITHIN 90 DAYS",count:s3.length,headers:["H/C","DESIGNATION","P/N","S/N","NEXT 18M","NEXT 36M","DAYS LEFT"],rows:s3,colW:cw34,daysCol:6});
  buildSlide(prs,{accent:"1E6BB5",title:"EFS Cylinders",subtitle:"DUE WITHIN 90 DAYS",headerLabel:"SERVICEABLE EFS CYLINDERS — DUE WITHIN 90 DAYS",count:s4.length,headers:["H/C","DESIGNATION","P/N","S/N","NEXT 18M","NEXT 60M","DAYS LEFT"],rows:s4,colW:cw34,daysCol:6});

  await prs.writeFile({fileName:OUTPUT});
  console.log(`\n✅  ${OUTPUT}`);
  console.log("=".repeat(55));
}

main().catch(e=>{console.error("FATAL:",e);process.exit(1);});
