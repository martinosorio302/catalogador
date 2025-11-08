import React from 'react'
export const Button = (p: any) => <button {...p} className={"btn "+(p.className||'')} />
export const Card = (p: any) => <div {...p} className={"card "+(p.className||'')} />
export const Input = (p: any) => <input {...p} className={"inp "+(p.className||'')} />
export const Label = (p: any) => <label {...p} className={"lbl "+(p.className||'')} />
export const Tabs = (p: any) => <div {...p} />
export const TabsList = (p: any) => <div {...p} className={"tabs "+(p.className||'')} />
export const TabsTrigger = ({value, children, ...rest}: any) => <button data-value={value} {...rest} className="tab" onClick={(e)=>{
  const root = (e.currentTarget.closest('.card')||document) as HTMLElement
  root.querySelectorAll('[data-tab]').forEach(el=>el.classList.add('hide'))
  root.querySelector(`[data-tab="${value}"]`)?.classList.remove('hide')
}}>{children}</button>
export const TabsContent = ({value, children}: any) => <div data-tab={value}>{children}</div>
export const Badge = (p: any) => <span {...p} className={"badge "+(p.className||'')} />
export const Progress = ({value=0}: any) => <div className="prog"><div style={{width:`${value}%`}}/></div>
