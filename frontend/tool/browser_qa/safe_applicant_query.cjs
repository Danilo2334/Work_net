'use strict';
module.exports=url=>{
  if(!/^\/company\/offers\/[1-9]\d*\/applicants$/.test(url.pathname))return false;
  const allowed=new Set(['page','page_size','order','experience','education','skill']);
  for(const [key,value]of url.searchParams){
    if(!allowed.has(key)||url.searchParams.getAll(key).length!==1)return false;
    if(key==='page'||key==='page_size'){
      if(!/^[1-9]\d*$/.test(value)||Number(value)>2147483647||(key==='page_size'&&value!=='10'))return false;
    }else if(key==='order'){
      if(!['newest','oldest','name','name_desc'].includes(value))return false;
    }else if(value.length>100||/[\x00-\x1f\x7f]/.test(value))return false;
  }
  return true;
};
