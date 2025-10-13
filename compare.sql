with
    BA_LTV as (
        select customerID
            , (
                (
                    (sum(amountlost)-sum(amountwon))
                    +(sum(debitadjustmentamount)-sum(creditadjustmentamount))
                    +(sum(casinoamountlost)-sum(casinoamountwon))
                )/100
              )*-1 as [BA LTV]
		from [GBSDev2].dbo.tbDailyFigure
        group by customerID

    ),
    BD_LTV as (
        select customerID
            , (
                (
                    (sum(amountlost)-sum(amountwon))
                    +(sum(debitadjustmentamount)-sum(creditadjustmentamount))
                    +(sum(casinoamountlost)-sum(casinoamountwon))
                )/100
              )*-1 as [BD LTV]
		from [BettorsDenDev].dbo.tbDailyFigure
        group by customerID

    ),
    BA as (
        select 
              EMail as [BA EMail]
            , trim(c.CustomerID) as [BA CustomerID]
            , Active as [BA Active]
            , cast(OpenDateTime as date) as [BA Registration Date]
            , cast(LastDepositDateTime as date) as [BA Last Deposit Date]
            , CurrentBalance/100.0 as [BA Current Balance]
            , cast(SessionLastActivity as date) as [BA Last Session Activity]
            , cid as [BA CID]            
            , InetTarget as [BA InetTarget]
            , coalesce(bl.[BA LTV], 0) as [BA LTV]
            , case when c.AgentType in ('M', 'A') then AffiliateID else null end as [BA AffiliateID]
            , AgentID as [BA AgentID]
        from GBSDev2..tbCustomer c
        left join BA_LTV bl on bl.CustomerID = upper(trim(c.CustomerID))
        where cid < 312448 -- magic number - max CID after restore from production, same effect as: OpenedBy <> 'Migration'
    ),
    BD_LastDeposit as (
        select
            upper(trim([CustomerID])) as CustomerID
            , cast(max([DepositDate]) as date) as LastDepositDate
        from 
            [BettorsDenDev].[dbo].[tbRHDeposit]
        group by
            upper(trim([CustomerID]))
        having
            max([DepositDate]) is not null
    ),
    BD_LastLogin as (
        select
              upper(trim(LoginID)) as CustomerID
            , max(AccessDateTime) as SessionLastActivity
        from
            [BettorsDenDev].[dbo].tbInetAccessLog
        where
            Operation like 'Login Success%'
        group by
            upper(trim(LoginID))
    ),
    BD as (
        select
            EMail as [BD EMail]
            , trim(c.CustomerID) as [BD CustomerID]
            , Active as [BD Active]
            , cast(OpenDateTime as date) as [BD Registration Date]
            , LastDepositDate as [BD Last Deposit Date]
            , CurrentBalance/100.0 as [BD Current Balance]
            , cast(bl.SessionLastActivity as date) as [BD Last Session Activity]
            , cid as [BD CID]
            , InetTarget as [BD InetTarget]
            , coalesce(bdl.[BD LTV], 0) as [BD LTV]
        from BettorsDenDev..tbCustomer c
        left join BD_LastDeposit bd on bd.CustomerID = trim(c.CustomerID)
        left join BD_LastLogin bl on bl.CustomerID = trim(c.CustomerID)
        left join BD_LTV bdl on bdl.CustomerID = upper(trim(c.CustomerID))
        where coalesce(email, '') <> ''
        and (c.IsAffiliate is null or c.IsAffiliate = 0)
        and OpenedBy = 'Internet'
    )
SELECT
    bd.[BD EMail]
    , bd.[BD CustomerID]
    , coalesce(string_agg(ba.[BA CustomerID], ', '), '') as [BA CustomerIDs]
    , coalesce(string_agg(ba.[BA AffiliateID], ', '), '') as [BA AffiliateIDs]
    , coalesce(string_agg(ba.[BA AgentID], ', '), '') as [BA AgentIDs]
    , coalesce(bd.[BD LTV], 0) as [BD LTV]
    , coalesce(sum(ba.[BA LTV]), 0) as [BA LTV]
    , bd.[BD Last Session Activity]
    , max(ba.[BA Last Session Activity]) as [BA Last Session Activity]
    , bd.[BD Last Deposit Date]
    , max(ba.[BA Last Deposit Date]) as [BA Last Deposit Date]
    , bd.[BD Current Balance]
    , sum(ba.[BA Current Balance]) as[BA Current Balance]
    , bd.[BD Registration Date]
    , min(ba.[BA Registration Date]) as [BA Registration Date]
    , [BD Active]
    , coalesce(string_agg(ba.[BA Active], ', '), '') as [BA Active]
    , bd.[BD CID]
    , bd.[BD InetTarget]
    , coalesce(string_agg(ba.[BA InetTarget], ', '), '') as [BA InetTarget]
    , case when bad.[BA CustomerID] is not null then 'Ivan Clash' else '' end as [Customer ID In Both]
    from bd 
    left join ba on ba.[BA EMail] = bd.[BD EMail]
    left join ba bad on bad.[BA CustomerID] = bd.[BD CustomerID]
    group by
        bd.[BD EMail]
        , bd.[BD CustomerID]
        , bd.[BD Last Deposit Date]
        , bd.[BD Current Balance]
        , bd.[BD CID]
        , bd.[BD InetTarget]
        , bd.[BD LTV]
        , bd.[BD Registration Date]
        , bd.[BD Active]
        , bd.[BD Last Session Activity]
        , case when bad.[BA CustomerID] is not null then 'Ivan Clash' else '' end
order by bd.[BD EMail]
;
