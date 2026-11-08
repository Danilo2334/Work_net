'use strict';
module.exports=url=>{
  if(url.pathname!=='/messages')return false;
  for(const[key,value]of url.searchParams){
    if(!['q','page'].includes(key)||url.searchParams.getAll(key).length!==1)return false;
    if(key==='page'){if(!/^[1-9]\d*$/.test(value)||Number(value)>2147483647)return false;}
    else if(value.length>100||/[\x00-\x1f\x7f]/.test(value))return false;
  }
  return true;
};
