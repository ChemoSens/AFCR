#' analyseSores
#'
#' Returns the plots with the scores according to their concentrations
#' @inheritParams getThreshold
#' @inheritParams keepLastOccurence
#' @param triangular if NULL, the obtained triangular thresholds are not represented on the graph. If not NULL, contains the dataset containing the results of AFC test containing these columns: subjectName, productName,descriptorName,timeName
#' @param scoreName name of the column containing the scores in rata data.frame
#' @param decreasingNumConcentrations numerical values of the used concentrations
#' @param revertX if TRUE, allows the x-axis the to be inverted
#' @param regression if TRUE, adds a linear regression and its statistical indicators (R2, RMSE) to the graph
#' @param displayAFC if TRUE, the AFC result is displayed (a point when the AFC test was succeeded, a cross if it was failed )
#' @importFrom forcats fct_relevel
#' @importFrom ggplot2 labs geom_abline scale_shape_manual geom_line theme_bw ggtitle aes ggplot geom_point
#' @importFrom stats coef lm
#' @export
#' @examples
#' data(rata)
#' p=analyseScores(rata,decreasingConcentrations=c("C9","C8","C7","C6","C5","C4","C3","C2","C1"),
#' subjectName="Paneliste",productName="Produit",scoreName="Score")
#' p
#' data(triangular)
#' p=analyseScores(rata,decreasingConcentrations=c("C9","C8","C7","C6","C5","C4","C3","C2","C1"),
#' subjectName="Paneliste",productName="Produit",scoreName="Score",triangular=triangular)
analyseScores=function(rata,decreasingConcentrations=c("C9","C8","C7","C6","C5","C4","C3","C2","C1"),subjectName="Panéliste",productName="Produit",descriptorName="Descripteur",timeName="Temps",resName="Res",scoreName="Score",
                       triangular=NULL,displayAFC=FALSE,decreasingNumConcentrations=NULL,regression=FALSE, revertX=FALSE, logY=FALSE,minConc=0,maxConc=NULL)
{
  subject=score=concentration=concentration2=Res=NULL
  rata2=rata[,c(productName,subjectName,scoreName)]
  colnames(rata2)=c("concentration","subject","score")
  rata2[,"concentration"]=factor(rata2[,"concentration"])
  if(!revertX)
    {
      rata2[,"concentration"]=fct_relevel(rata2[,"concentration"],decreasingConcentrations)
    }
  if(revertX& is.null(decreasingNumConcentrations))
  {
    rata2[,"concentration"]=fct_relevel(rata2[,"concentration"],rev(decreasingConcentrations))
  }

  if(!is.null(decreasingNumConcentrations))
  {
    rata2[,"concentration2"]=rata2[,"concentration"]
    correspondance=decreasingNumConcentrations
    names(correspondance)=decreasingConcentrations
    rata2[,"concentration2"]=correspondance[as.character(rata2[,"concentration2"])]
  }
  if(logY){rata2[,"score"]=log(rata2[,"score"]+1)}
   if(!is.null(decreasingNumConcentrations))
   {
     p=ggplot(rata2,aes(x=concentration2,y=score,group=subject,color=subject))+geom_line()+theme_bw()+ggtitle("Scores according to concentrations")
   }
  else
  {
    p=ggplot(rata2,aes(x=concentration,y=score,group=subject,color=subject))+geom_line()+theme_bw()+ggtitle("Scores according to concentrations")
  }
  r2=rmse=r2n=rmsen=slopeNeg=slopePos=NA
  if(!is.null(triangular))
  {
     res=keepLastOccurence(triangular,subjectName=subjectName,productName=productName,descriptorName=descriptorName,timeName=timeName)
     thr=getThreshold(res,decreasingConcentrations=decreasingConcentrations,subjectName=subjectName,productName=productName,descriptorName=descriptorName,timeName=timeName,resName=resName,rata=rata,decreasingNumConcentrations=decreasingNumConcentrations,minConc=minConc,maxConc=maxConc)
     wrongs=res$df
     if("avg"%in%colnames(thr))
     {
       thr2=thr[,c(productName,subjectName,"score","avg","thresholdNum")]
       colnames(thr2)=c("concentration","subject","score","avg","thresholdNum")
     }
     else
     {
       thr2=thr[,c(productName,subjectName,"score")]
       colnames(thr2)=c("concentration","subject","score")
     }

     if(logY){thr2[,"score"]=log(thr2[,"score"]+1)}
     if(is.null(decreasingNumConcentrations))
     {
         p=p+geom_point(data=thr2,mapping=aes(x=concentration,y=score,col=subject),size=4,shape=2)
     }
    if(!is.null(decreasingNumConcentrations))
    {

      thr2[,"concentration2"]=correspondance[as.character(thr2[,"concentration"])]
      p=p+geom_point(data=thr2,mapping=aes(x=thresholdNum,y=avg,col=subject),size=4,shape=2)
    }

    if(displayAFC)
     {
       df_wrong=merge(rata2,wrongs,by.y=c(subjectName,productName),by.x=c("subject","concentration"),all.x=TRUE)
       df_wrong=df_wrong[!is.na(df_wrong[,"Res"]),]
       if(is.null(decreasingNumConcentrations))
       {
         p=p+geom_point(data=df_wrong,mapping=aes(x=concentration,y=score,col=subject,shape=Res))+scale_shape_manual(values=c("OK"=20,"KO"=4))
       }
        if(!is.null(decreasingNumConcentrations))
       {
         p=p+geom_point(data=df_wrong,mapping=aes(x=concentration2,y=score,col=subject,shape=Res))+scale_shape_manual(values=c("OK"=20,"KO"=4))
       }
    }
    subtitle=""
     if(regression & !is.null(decreasingNumConcentrations)&length(unique(rata[,subjectName]))==1)
     {
       relevantDataPos=rata2[,"concentration2"]>=thr2[,"concentration2"]
       relevantDataNeg=rata2[,"concentration2"]<thr2[,"concentration2"]

       if(sum(relevantDataPos)>2)
       {
         reslm=lm(rata2[relevantDataPos,"score"]~rata2[relevantDataPos,"concentration2"])
         r2=summary(reslm)$adj.r.squared
         ssr=sum(summary(reslm)$residuals^2)
         rmse=sqrt(ssr/length(summary(reslm)$residuals))
         if(subtitle==""){subtitle=paste0("R2: ",round(summary(reslm)$r.squared,digits=2),"; RMSE:", round(rmse,2))}
         p=p + geom_abline(intercept = coef(reslm)[1], slope = coef(reslm)[2], col="blue") + labs(subtitle=subtitle)
         slopePos=coef(reslm)[1]
       }

       if(sum(relevantDataNeg)>2)
       {
         reslm=lm(rata2[relevantDataNeg,"score"]~rata2[relevantDataNeg,"concentration2"])
         r2n=summary(reslm)$adj.r.squared
         ssr=sum(summary(reslm)$residuals^2)
         rmsen=sqrt(ssr/length(summary(reslm)$residuals))
         slopeNeg=coef(reslm)[1]
         subtitle=paste0(subtitle, "R2n: ",round(summary(reslm)$r.squared,digits=2),"; RMSEn:", round(rmse,2),"; slope:",round(slopeNeg,digit=1))
         p=p + geom_abline(intercept = coef(reslm)[1], slope = coef(reslm)[2], col="green") + labs(subtitle=subtitle)
       }
     }
  }

  listRes=list(p=p,r2=r2,rmse=rmse,r2n=r2n,rmsen=rmsen,slopeNeg=slopeNeg,slopePos=slopePos)
  return(listRes)
}